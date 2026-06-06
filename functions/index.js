const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {defineSecret} = require("firebase-functions/params");
const logger = require("firebase-functions/logger");
const admin = require("firebase-admin");

admin.initializeApp();

const geminiApiKey = defineSecret("GEMINI_API_KEY");
const hfApiKey = defineSecret("HF_API_KEY");
const geminiModerationModel = "gemini-2.0-flash";
const hfTextModerationModel = "google/gemma-3-27b-it";
const region = "asia-southeast1";
const blockedVietnamesePhrases = [
  "du ma",
  "dm",
  "dmm",
  "dit me",
  "djt me",
  "dit con me",
  "cai lon",
  "con cac",
  "cc",
  "cl",
  "clm",
  "vl",
  "vcl",
];

exports.moderateText = onCall(
  {region, secrets: [hfApiKey], timeoutSeconds: 60},
  async (request) => {
    await requireSignedIn(request);

    const text = String(request.data && request.data.text ? request.data.text : "").trim();
    const context = String(request.data && request.data.context ? request.data.context : "text");
    if (!text) {
      throw new HttpsError("invalid-argument", "Text is required.");
    }

    const profanityResult = detectVietnameseProfanity(text);
    if (profanityResult) {
      return rejectedByLocalTextFilter(context, profanityResult);
    }

    const result = await callHuggingFaceTextModeration({
      text,
      context,
    });

    return toClientResult(result, {
      context,
      inputType: "text",
      checkedBy: "huggingface_gemma",
      model: hfTextModerationModel,
    });
  },
);

exports.moderateImage = onCall(
  {region, secrets: [geminiApiKey], timeoutSeconds: 60, memory: "512MiB"},
  async (request) => {
    await requireSignedIn(request);

    const imageDataUrl = String(
      request.data && request.data.imageDataUrl ? request.data.imageDataUrl : "",
    );
    const fileName = String(request.data && request.data.fileName ? request.data.fileName : "");
    const index = Number.isInteger(request.data && request.data.index)
      ? request.data.index
      : null;

    if (!imageDataUrl.startsWith("data:image/")) {
      throw new HttpsError("invalid-argument", "A valid image data URL is required.");
    }

    const result = await callGeminiModeration({
      inputType: "image",
      imageDataUrl,
      context: "post_image",
    });

    return toClientResult(result, {
      inputType: "image",
      fileName,
      index,
      checkedBy: "gemini_api",
      model: geminiModerationModel,
    });
  },
);

async function requireSignedIn(request) {
  if (request.auth) {
    return request.auth;
  }

  const authToken = String(request.data && request.data.authToken ? request.data.authToken : "");
  if (!authToken) {
    throw new HttpsError("unauthenticated", "You must sign in to moderate content.");
  }

  try {
    const decodedToken = await admin.auth().verifyIdToken(authToken);
    return {uid: decodedToken.uid, token: decodedToken};
  } catch (error) {
    logger.warn("Invalid moderation auth token", {message: error.message});
    throw new HttpsError("unauthenticated", "You must sign in to moderate content.");
  }
}

function detectVietnameseProfanity(text) {
  const normalized = normalizeVietnameseText(text);
  const compact = normalized.replace(/\s+/g, "");

  for (const phrase of blockedVietnamesePhrases) {
    const normalizedPhrase = normalizeVietnameseText(phrase);
    const compactPhrase = normalizedPhrase.replace(/\s+/g, "");
    const phrasePattern = new RegExp(
      `(^|\\s)${escapeRegExp(normalizedPhrase)}($|\\s)`,
      "i",
    );

    if (
      phrasePattern.test(normalized) ||
      (compactPhrase.length >= 4 && compact.includes(compactPhrase))
    ) {
      return {
        phrase,
        normalizedPhrase,
      };
    }
  }

  return null;
}

function normalizeVietnameseText(text) {
  return String(text)
    .toLowerCase()
    .replace(/[\u0111\u0110]/g, "d")
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .replace(/[^a-z0-9]+/g, " ")
    .trim();
}

function escapeRegExp(text) {
  return text.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

function rejectedByLocalTextFilter(context, profanityResult) {
  return {
    passed: false,
    violations: ["Noi dung co tu ngu tho tuc hoac xuc pham."],
    message: "Noi dung co tu ngu khong phu hop.",
    details: {
      context,
      inputType: "text",
      checkedBy: "local_vietnamese_filter",
      blockedPhrase: profanityResult.normalizedPhrase,
    },
  };
}

async function callGeminiModeration({inputType, text, imageDataUrl, context}) {
  const url = `https://generativelanguage.googleapis.com/v1beta/models/${geminiModerationModel}:generateContent?key=${geminiApiKey.value()}`;
  const parts = [{text: buildModerationPrompt({inputType, context})}];

  if (inputType === "image") {
    const image = parseImageDataUrl(imageDataUrl);
    parts.push({
      inline_data: {
        mime_type: image.mimeType,
        data: image.base64,
      },
    });
  } else {
    parts.push({text: `Noi dung can kiem duyet:\n${text}`});
  }

  const response = await fetch(url, {
    method: "POST",
    headers: {"Content-Type": "application/json"},
    body: JSON.stringify({
      contents: [
        {
          role: "user",
          parts,
        },
      ],
      generationConfig: {
        temperature: 0,
        responseMimeType: "application/json",
      },
    }),
  });

  const payload = await response.json().catch(() => ({}));
  if (!response.ok) {
    logger.error("Gemini moderation failed", {
      status: response.status,
      payload,
    });

    if (isGeminiQuotaExhausted(response.status, payload)) {
      logger.warn("Gemini quota exhausted; allowing content after local checks", {
        inputType,
        context,
        model: geminiModerationModel,
      });
      return {
        flagged: false,
        categories: {},
        category_scores: {},
        violations: [],
        rawMessage: "Gemini quota exhausted; passed by local fallback.",
        fallbackReason: "gemini_quota_exhausted",
      };
    }

    throw new HttpsError(
      "internal",
      "Cannot moderate content right now. Please try again.",
    );
  }

  if (payload.promptFeedback && payload.promptFeedback.blockReason) {
    return {
      flagged: true,
      categories: {blocked_by_gemini_safety: true},
      category_scores: {},
      violations: [],
      rawMessage: `Gemini blocked request: ${payload.promptFeedback.blockReason}`,
    };
  }

  const content = payload.candidates &&
    payload.candidates[0] &&
    payload.candidates[0].content &&
    payload.candidates[0].content.parts &&
    payload.candidates[0].content.parts[0] &&
    payload.candidates[0].content.parts[0].text;

  if (!content) {
    throw new HttpsError("internal", "Gemini moderation response is empty.");
  }

  return parseModerationJsonResult(content);
}

async function callHuggingFaceTextModeration({text, context}) {
  const response = await fetch("https://router.huggingface.co/v1/chat/completions", {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${hfApiKey.value()}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      model: hfTextModerationModel,
      messages: [
        {
          role: "system",
          content: buildModerationPrompt({inputType: "text", context}),
        },
        {
          role: "user",
          content: `Noi dung can kiem duyet:\n${text}`,
        },
      ],
      temperature: 0,
      max_tokens: 220,
    }),
  });

  const payload = await response.json().catch(() => ({}));
  if (!response.ok) {
    logger.error("Hugging Face Gemma moderation failed", {
      status: response.status,
      payload,
    });

    if (response.status === 401 || response.status === 403) {
      throw new HttpsError(
        "failed-precondition",
        "HF_API_KEY does not have permission to call Hugging Face Inference Providers.",
      );
    }

    if (isProviderTemporarilyUnavailable(response.status, payload)) {
      logger.warn("Hugging Face unavailable; allowing content after local checks", {
        context,
        model: hfTextModerationModel,
      });
      return {
        flagged: false,
        categories: {},
        category_scores: {},
        violations: [],
        rawMessage: "Hugging Face unavailable; passed by local fallback.",
        fallbackReason: "huggingface_unavailable",
      };
    }

    throw new HttpsError(
      "internal",
      "Cannot moderate content right now. Please try again.",
    );
  }

  const content = payload.choices &&
    payload.choices[0] &&
    payload.choices[0].message &&
    payload.choices[0].message.content;

  if (!content) {
    logger.error("Hugging Face moderation response is empty", {payload});
    throw new HttpsError("internal", "Hugging Face moderation response is empty.");
  }

  return parseModerationJsonResult(content);
}

function buildModerationPrompt({inputType, context}) {
  return [
    "Ban la he thong kiem duyet noi dung cho ung dung tim phong tro.",
    "Hay phan loai noi dung co vi pham hay khong.",
    "Danh dau vi pham neu co: tu ngu tho tuc, xuc pham, quay roi, thu ghet, tinh duc, bao luc, lua dao, spam, noi dung bat hop phap, thong tin nguy hiem.",
    `Loai dau vao: ${inputType}. Ngu canh: ${context}.`,
    "Chi tra ve JSON hop le, khong markdown, theo mau:",
    "{\"flagged\":false,\"categories\":{\"profanity\":false,\"harassment\":false,\"hate\":false,\"sexual\":false,\"violence\":false,\"illegal\":false,\"scam\":false,\"spam\":false},\"violations\":[],\"reason\":\"\"}",
  ].join("\n");
}

function parseImageDataUrl(imageDataUrl) {
  const match = /^data:(image\/[a-zA-Z0-9.+-]+);base64,(.+)$/.exec(imageDataUrl);
  if (!match) {
    throw new HttpsError("invalid-argument", "A valid image data URL is required.");
  }
  return {
    mimeType: match[1],
    base64: match[2],
  };
}

function parseModerationJsonResult(content) {
  let parsed;
  try {
    parsed = JSON.parse(stripJsonCodeFence(content));
  } catch (error) {
    logger.error("Cannot parse moderation JSON", {content});
    throw new HttpsError("internal", "Moderation response is invalid.");
  }

  const categories = parsed.categories && typeof parsed.categories === "object"
    ? parsed.categories
    : {};
  const violations = Array.isArray(parsed.violations) ? parsed.violations : [];

  return {
    flagged: parsed.flagged === true || violations.length > 0,
    categories,
    category_scores: {},
    violations,
    rawMessage: String(parsed.reason || ""),
  };
}

function toClientResult(result, details) {
  const flaggedCategories = Object.entries(result.categories || {})
    .filter(([, flagged]) => flagged === true)
    .map(([category]) => category);
  const passed = result.flagged !== true && flaggedCategories.length === 0;
  const apiViolations = Array.isArray(result.violations) ? result.violations : [];
  const violations = apiViolations.length > 0
    ? apiViolations
    : flaggedCategories.map(categoryToVietnameseMessage);

  return {
    passed,
    violations,
    message: passed
      ? "Noi dung hop le."
      : "Noi dung khong phu hop tieu chuan cong dong.",
    details: {
      ...details,
      flagged: result.flagged === true,
      categories: result.categories || {},
      categoryScores: result.category_scores || {},
      model: details.model || null,
      rawMessage: result.rawMessage || "",
      fallbackReason: result.fallbackReason || null,
    },
  };
}

function stripJsonCodeFence(content) {
  return String(content)
    .trim()
    .replace(/^```json\s*/i, "")
    .replace(/^```\s*/i, "")
    .replace(/\s*```$/i, "")
    .trim();
}

function isGeminiQuotaExhausted(status, payload) {
  if (status === 429) {
    return true;
  }

  const error = payload && payload.error ? payload.error : {};
  return error.status === "RESOURCE_EXHAUSTED" || error.code === 429;
}

function isProviderTemporarilyUnavailable(status, payload) {
  if ([429, 500, 502, 503, 504].includes(status)) {
    return true;
  }

  const error = payload && payload.error ? payload.error : {};
  return error.status === "RESOURCE_EXHAUSTED" ||
    error.code === 429 ||
    error.code === "model_not_supported";
}

function categoryToVietnameseMessage(category) {
  const labels = {
    harassment: "Noi dung co dau hieu quay roi hoac cong kich.",
    hate: "Noi dung co dau hieu thu ghet hoac phan biet doi xu.",
    sexual: "Noi dung co dau hieu tinh duc khong phu hop.",
    violence: "Noi dung co dau hieu bao luc.",
    profanity: "Noi dung co tu ngu tho tuc hoac xuc pham.",
    illegal: "Noi dung co dau hieu bat hop phap.",
    scam: "Noi dung co dau hieu lua dao.",
    spam: "Noi dung co dau hieu spam.",
    blocked_by_gemini_safety: "Noi dung bi chan boi bo loc an toan cua Gemini.",
  };
  return labels[category] || `Noi dung vi pham danh muc ${category}.`;
}

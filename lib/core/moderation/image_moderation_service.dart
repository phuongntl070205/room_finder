import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

import 'moderation_result.dart';

class ImageModerationService {
  ImageModerationService();

  static const int maxImages = 10;
  static const int maxImageBytes = 5 * 1024 * 1024;
  static const double minRoomConfidence = 0.60;
  static const String invalidClassName = 'Invalid';
  static const Set<String> allowedExtensions = {
    '.jpg',
    '.jpeg',
    '.png',
    '.webp',
  };

  static const Set<String> validRoomClasses = {
    'Bathroom',
    'Bedroom',
    'Dinning',
    'Kitchen',
    'Livingroom',
  };

  static Future<Interpreter>? _interpreterFuture;
  static Future<List<String>>? _labelsFuture;

  Future<ModerationResult> moderateImages(List<File> images) async {
    if (images.isEmpty) {
      return ModerationResult.rejected(
        violations: const ['Cần ít nhất 1 ảnh cho bài đăng.'],
        message: 'Cần ít nhất 1 ảnh cho bài đăng.',
        details: {'source': 'client_validation'},
      );
    }

    if (images.length > maxImages) {
      return ModerationResult.rejected(
        violations: const ['Chỉ được chọn tối đa 10 ảnh.'],
        message: 'Chỉ được chọn tối đa 10 ảnh cho mỗi bài đăng.',
        details: {'source': 'client_validation', 'maxImages': maxImages},
      );
    }

    final violations = <String>[];
    final moderationDetails = <Map<String, dynamic>>[];

    for (var i = 0; i < images.length; i++) {
      final file = images[i];
      final fileName = _fileName(file.path);
      final extension = _extension(file.path);

      if (!allowedExtensions.contains(extension)) {
        violations.add(
          'Ảnh ${i + 1} ($fileName) không đúng định dạng jpg, jpeg, png hoặc webp.',
        );
        continue;
      }

      final size = await file.length();
      if (size > maxImageBytes) {
        violations.add(
          'Ảnh ${i + 1} ($fileName) vượt quá dung lượng 5MB.',
        );
        continue;
      }

      final result = await _classifyRoomImage(file);
      moderationDetails.add(result);

      final label = result['label']?.toString() ?? '';
      final confidence = (result['confidence'] as num?)?.toDouble() ?? 0;
      if (!_isValidRoomLabel(label) || confidence < minRoomConfidence) {
        violations.add(
          'Ảnh ${i + 1} ($fileName) không phải ảnh phòng trọ hợp lệ. Vui lòng tải ảnh phòng/không gian thực tế.',
        );
      }
    }

    if (violations.isNotEmpty) {
      return ModerationResult.rejected(
        violations: violations,
        message: 'Một số ảnh không đạt yêu cầu kiểm duyệt.',
        details: {
          'source': 'local_room_filter_model',
          'imageResults': moderationDetails,
        },
      );
    }

    return ModerationResult.passed(
      message: 'Tất cả ảnh hợp lệ.',
      details: {
        'source': 'local_room_filter_model',
        'imageResults': moderationDetails,
      },
    );
  }

  Future<Map<String, dynamic>> _classifyRoomImage(File file) async {
    final interpreter = await _loadInterpreter();
    final labels = await _loadLabels();

    final bytes = await file.readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      return {
        'fileName': _fileName(file.path),
        'label': invalidClassName,
        'confidence': 1.0,
        'scores': <String, double>{},
        'error': 'decode_failed',
      };
    }

    final inputShape = interpreter.getInputTensor(0).shape;
    if (inputShape.length != 4) {
      throw StateError('Unsupported image model input shape: $inputShape');
    }

    final height = inputShape[1];
    final width = inputShape[2];
    final channels = inputShape[3];
    if (channels != 3) {
      throw StateError('Unsupported image model channel count: $channels');
    }

    final resized = img.copyResize(decoded, width: width, height: height);
    final input = _buildFloatInput(resized, width, height);
    final outputShape = interpreter.getOutputTensor(0).shape;
    final outputSize = outputShape.reduce((a, b) => a * b);
    final output = List.filled(outputSize, 0.0).reshape([1, outputSize]);

    interpreter.run(input, output);

    final rawScores = List<double>.from(output.first);
    final scores = _normalizeScores(rawScores);
    final bestIndex = _bestIndex(scores);
    final label = bestIndex < labels.length ? labels[bestIndex] : 'unknown';
    final confidence = scores[bestIndex];

    return {
      'fileName': _fileName(file.path),
      'label': label,
      'confidence': confidence,
      'scores': {
        for (var i = 0; i < min(labels.length, scores.length); i++)
          labels[i]: scores[i],
      },
      'inputShape': inputShape,
      'outputShape': outputShape,
    };
  }

  List<List<List<List<double>>>> _buildFloatInput(
    img.Image image,
    int width,
    int height,
  ) {
    return [
      List.generate(height, (y) {
        return List.generate(width, (x) {
          final pixel = image.getPixel(x, y);
          return [
            pixel.r / 255.0,
            pixel.g / 255.0,
            pixel.b / 255.0,
          ];
        });
      }),
    ];
  }

  List<double> _normalizeScores(List<double> values) {
    if (values.isEmpty) return values;
    final sum = values.fold<double>(0, (total, value) => total + value);
    final alreadyProbability =
        values.every((value) => value >= 0 && value <= 1) &&
            sum > 0.99 &&
            sum < 1.01;
    if (alreadyProbability) return values;

    final maxValue = values.reduce(max);
    final exps = values.map((value) => exp(value - maxValue)).toList();
    final expSum = exps.fold<double>(0, (total, value) => total + value);
    return expSum == 0 ? values : exps.map((value) => value / expSum).toList();
  }

  int _bestIndex(List<double> values) {
    var bestIndex = 0;
    var bestScore = values.first;
    for (var i = 1; i < values.length; i++) {
      if (values[i] > bestScore) {
        bestScore = values[i];
        bestIndex = i;
      }
    }
    return bestIndex;
  }

  bool _isValidRoomLabel(String label) {
    return validRoomClasses.contains(label) && label != invalidClassName;
  }

  Future<Interpreter> _loadInterpreter() {
    _interpreterFuture ??= Interpreter.fromAsset(
      'assets/models/room_filter_model.tflite',
    );
    return _interpreterFuture!;
  }

  Future<List<String>> _loadLabels() async {
    _labelsFuture ??= rootBundle
        .loadString('assets/models/class_names.json')
        .then((value) => List<String>.from(jsonDecode(value) as List));
    return _labelsFuture!;
  }

  String _fileName(String path) {
    final normalized = path.replaceAll('\\', '/');
    final slashIndex = normalized.lastIndexOf('/');
    return slashIndex == -1 ? normalized : normalized.substring(slashIndex + 1);
  }

  String _extension(String path) {
    final fileName = _fileName(path).toLowerCase();
    final dotIndex = fileName.lastIndexOf('.');
    return dotIndex == -1 ? '' : fileName.substring(dotIndex);
  }
}

# Room Finder

Room Finder là ứng dụng Flutter/Firebase hỗ trợ sinh viên và người thuê trọ tìm phòng, đăng bài cho thuê phòng, tìm bạn ở ghép, lưu bài, bình luận công khai và nhắn tin riêng.

## Chức năng chính

- Đăng nhập bằng Google qua Firebase Authentication.
- Xem danh sách bài đăng phòng trọ và bài tìm bạn ở ghép.
- Đăng bài cho thuê phòng với ảnh thực tế, địa chỉ, giá thuê, chi phí điện/nước/dịch vụ và tiện ích.
- Đăng bài tìm bạn ở ghép, cho phép không tải ảnh.
- Lưu/bỏ lưu bài đăng vào hồ sơ cá nhân.
- Bình luận công khai dưới bài đăng.
- Chat riêng giữa các người dùng, không kiểm duyệt nội dung chat.
- Kiểm duyệt nội dung công khai trước khi đăng/cập nhật.

## Kiểm duyệt nội dung

Ứng dụng không dùng luồng admin duyệt thủ công cho bài đăng hợp lệ. Khi người dùng đăng hoặc cập nhật bài, hệ thống kiểm tra ngay:

- Nội dung chữ: gọi Cloud Function `moderateText`, có kiểm tra nhanh danh sách từ nhạy cảm tiếng Việt và gọi Hugging Face/Gemma khi có API key hợp lệ.
- Ảnh bài cho thuê: kiểm tra local bằng model TFLite `room_filter_model.tflite`.
- Bình luận công khai: kiểm duyệt nội dung chữ trước khi lưu.
- Chat riêng: không kiểm duyệt theo yêu cầu nghiệp vụ hiện tại.

Nếu vi phạm, app báo lỗi ngay để người dùng sửa nội dung hoặc tải ảnh khác. Bài hợp lệ được lưu với `status = published` và `moderationStatus = approved`.

## Ràng buộc đăng bài

| Luồng | Ràng buộc chính |
| --- | --- |
| Cho thuê phòng | Bắt buộc có ít nhất 1 ảnh, tối đa 10 ảnh |
| Cho thuê phòng | Giá thuê tối thiểu 1.000.000 VND, không đặt giá tối đa |
| Cho thuê phòng | Ảnh phải là ảnh phòng/không gian hợp lệ theo model local |
| Tìm bạn ở ghép | Ảnh không bắt buộc, nếu có ảnh thì tối đa 10 ảnh và vẫn được kiểm tra |
| Nội dung công khai | Không chứa từ ngữ nhạy cảm/spam/không phù hợp |
| Cập nhật bài | Kiểm tra lại nội dung và ảnh mới trước khi lưu |

## Công nghệ sử dụng

- Flutter/Dart
- Firebase Authentication
- Cloud Firestore
- Firebase Storage
- Firebase Cloud Functions v2
- Google Sign-In
- Google Maps, Geolocator, Geocoding
- Hugging Face Inference Providers cho kiểm duyệt text
- TensorFlow Lite (`tflite_flutter`) cho kiểm duyệt ảnh local

## Cấu trúc thư mục chính

```text
lib/
  core/
    moderation/          # Kiểm duyệt text và ảnh
    config/              # Cấu hình map
  data/
    models/              # ListingModel, UserModel, ChatModel
    services/            # Auth, Post, Storage, Chat, User
  presentation/
    pages/               # Màn hình chính của app
    widgets/             # Widget dùng lại
  features/user/         # Các màn hình user mở rộng

assets/
  models/                # room_filter_model.tflite, class_names.json

functions/               # Firebase Cloud Functions
firestore.rules          # Firestore Security Rules
storage.rules            # Firebase Storage Rules
```

## Cài đặt và chạy

```bash
flutter pub get
flutter run
```

Project Firebase hiện được cấu hình trong `firebase.json` với project ID `roomfinder-1b0e2`. Android app dùng `android/app/google-services.json` và Flutter options ở `lib/firebase_options.dart`.

## Cấu hình Firebase Functions

Cloud Function kiểm duyệt nội dung chữ cần secret:

```bash
firebase functions:secrets:set HF_API_KEY
```

Function `moderateImage` cũ vẫn còn trong backend và dùng `GEMINI_API_KEY`, nhưng luồng app hiện tại kiểm duyệt ảnh bằng model TFLite local.

```bash
firebase functions:secrets:set GEMINI_API_KEY
```

Deploy rules và functions:

```bash
firebase deploy --only firestore:rules,storage
firebase deploy --only functions
```

## Model lọc ảnh

Model đang dùng:

- `assets/models/room_filter_model.tflite`
- `assets/models/class_names.json`

Danh sách class hiện tại:

```json
["Bathroom", "Bedroom", "Dinning", "Invalid", "Kitchen", "Livingroom"]
```

Ảnh hợp lệ khi model dự đoán một trong các class phòng/không gian hợp lệ với confidence tối thiểu `0.60`. Ảnh thuộc class `Invalid`, sai định dạng hoặc quá 5MB sẽ bị chặn.

## Build APK

```bash
flutter build apk --debug
```

APK debug được tạo tại:

```text
build/app/outputs/flutter-apk/app-debug.apk
```

## Trạng thái hiện tại

Project đã đủ điều kiện chạy demo/MVP cho các luồng chính: đăng nhập, đăng bài, tìm bạn ở ghép, kiểm duyệt text, kiểm duyệt ảnh local, bình luận, lưu bài và chat.

Một số điểm cần tiếp tục hoàn thiện trước khi dùng production:

- Kiểm duyệt bài đăng hiện chủ yếu được quyết định từ client rồi ghi `published/approved`, cần tăng kiểm tra phía server để chống app bị chỉnh sửa.
- Storage rule cho `posts/{postId}` cho phép mọi user đã đăng nhập upload ảnh vào bất kỳ `postId`; nên ràng buộc quyền sở hữu bài đăng.
- Một số enum/trang admin duyệt thủ công cũ vẫn còn trong code nhưng không còn là luồng nghiệp vụ chính.
- Cần bổ sung test tự động cho validation, rules và Cloud Functions.

## Checklist test thủ công

- Đăng nhập Google thành công và tạo user trong Firestore.
- Đăng bài cho thuê thiếu ảnh và kiểm tra app báo lỗi.
- Đăng bài cho thuê có hơn 10 ảnh và kiểm tra app báo lỗi.
- Đăng bài cho thuê giá dưới 1.000.000 VND và kiểm tra app báo lỗi.
- Nhập nội dung có từ nhạy cảm và kiểm tra app chặn trước khi lưu.
- Đăng bài với ảnh không phải phòng trọ và kiểm tra app yêu cầu tải ảnh khác.
- Đăng bài hợp lệ và kiểm tra Firestore lưu `published/approved`.
- Cập nhật bài với nội dung/ảnh vi phạm và kiểm tra app chặn.
- Đăng bài tìm bạn ở ghép không có ảnh và kiểm tra vẫn đăng được nếu nội dung hợp lệ.
- Bình luận có từ nhạy cảm và kiểm tra app chặn.
- Chat riêng hoạt động giữa hai user.

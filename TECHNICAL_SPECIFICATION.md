# Technical Specification - Room Finder

## 1. Kết luận nhanh

Room Finder hiện đã đạt mức MVP tốt cho đồ án/demo: có đăng nhập, đăng bài, tìm bạn ở ghép, lọc nội dung công khai, lọc ảnh phòng trọ bằng model local, lưu bài, bình luận và chat. Luồng nghiệp vụ sau khi sửa phù hợp thực tế hơn vì không còn yêu cầu admin duyệt thủ công cho mọi bài đăng; người dùng nhận lỗi ngay khi nội dung hoặc ảnh không hợp lệ.

Mức hoàn thiện tổng quan ước tính: khoảng 75-80% cho MVP. Để dùng production, cần tăng kiểm tra phía server, siết Storage Rules, dọn code legacy và bổ sung test tự động.

## 2. Phạm vi đánh giá

Đánh giá dựa trên các phần chính trong project:

- Flutter UI và các flow người dùng trong `lib/`.
- Model dữ liệu trong `lib/data/models/`.
- Service trong `lib/data/services/`.
- Kiểm duyệt trong `lib/core/moderation/`.
- Firebase Cloud Functions trong `functions/index.js`.
- Firestore Rules trong `firestore.rules`.
- Firebase Storage Rules trong `storage.rules`.

Không đánh giá/sửa thư mục `lib_ver2`.

## 3. Kiến trúc hiện tại

| Thành phần | Vai trò |
| --- | --- |
| Flutter app | UI, nhập liệu, validation client, gọi Firebase services |
| Firebase Auth | Đăng nhập Google, định danh user |
| Cloud Firestore | Lưu users, listings, comments, chats, reports |
| Firebase Storage | Lưu ảnh bài đăng và avatar |
| Cloud Functions | Kiểm duyệt nội dung chữ bằng `moderateText` |
| Hugging Face/Gemma | Model kiểm duyệt text phía server |
| TFLite local model | Kiểm duyệt ảnh phòng trọ ngay trên thiết bị |
| Security Rules | Chặn truy cập trái phép cơ bản cho Firestore/Storage |

## 4. Cấu trúc dữ liệu chính

### ListingModel

`ListingModel` đại diện cho bài đăng cho thuê phòng hoặc tìm bạn ở ghép.

| Field | Ý nghĩa |
| --- | --- |
| `id` | ID document Firestore |
| `authorId` | UID người đăng |
| `postType` | `roomForRent` hoặc `roommateWanted` |
| `title` | Tiêu đề bài đăng |
| `description` | Mô tả bài đăng |
| `price` | Giá thuê/ngân sách |
| `status` | Trạng thái bài đăng |
| `location` | `GeoPoint` vị trí |
| `address` | Địa chỉ hiển thị |
| `addressComponents` | Thành phần địa chỉ đã phân giải |
| `mediaUrls` | Danh sách URL ảnh |
| `moderationStatus` | Trạng thái kiểm duyệt |
| `moderationResult` | Kết quả kiểm duyệt text/ảnh |
| `amenities` | Tiện ích phòng |
| `electricPrice`, `waterPrice`, `serviceFee`, `otherFee` | Chi phí phụ |

Lưu ý: enum `ListingStatus` vẫn còn `pending/rejected`, và `ModerationStatus` vẫn còn `pending_check/rejected`. Tuy nhiên luồng nghiệp vụ hiện tại dùng `published/approved` cho bài hợp lệ và chặn ngay bài vi phạm trước khi lưu.

### UserModel

`UserModel` lưu hồ sơ người dùng:

- `uid`, `email`, `displayName`, `avatarUrl`, `phoneNumber`.
- `role`: mặc định `user`, có hỗ trợ `admin` ở rules/code legacy.
- `habitTags`, `savedPostIds`, `budgetMin`, `budgetMax`, `preferredAreas`.

### ChatModel

`ChatModel` lưu hội thoại riêng:

- `participants`: danh sách UID.
- `lastMessage`, `lastMessageTime`, `lastMessageSenderId`.
- `unreadCount`.

## 5. Luồng nghiệp vụ chính

| Luồng | Trạng thái hiện tại | Nhận xét |
| --- | --- | --- |
| Đăng nhập Google | Hoạt động | Tạo user Firestore nếu chưa có |
| Đăng bài cho thuê | Hoạt động | Bắt buộc ảnh, lọc text, lọc ảnh, giá min 1.000.000 |
| Tìm bạn ở ghép | Hoạt động | Ảnh không bắt buộc, nếu có ảnh vẫn lọc |
| Cập nhật bài | Hoạt động | Kiểm tra lại text và ảnh mới trước khi update |
| Xem danh sách bài | Hoạt động | Chỉ hiển thị bài `published` theo rules/query |
| Lưu bài | Hoạt động | Lưu ID vào `users.savedPostIds`; hiện giới hạn query 10 ID |
| Bình luận công khai | Hoạt động | Gọi kiểm duyệt text trước khi lưu |
| Chat riêng | Hoạt động | Không kiểm duyệt theo yêu cầu nghiệp vụ |
| Admin duyệt bài | Không còn là flow chính | Code/trang cũ vẫn còn, nên dọn nếu không dùng |

## 6. Luồng đăng bài cho thuê

1. Người dùng nhập tiêu đề, mô tả, giá, địa chỉ, phí phụ và chọn ảnh.
2. App kiểm tra form client-side.
3. App bắt buộc có ít nhất 1 ảnh.
4. App giới hạn tối đa 10 ảnh.
5. App phân giải địa chỉ sang tọa độ.
6. App gọi `TextModerationService.moderateListing`.
7. Nếu nội dung vi phạm, app hiển thị lỗi và không upload ảnh/không lưu bài.
8. App gọi `ImageModerationService.moderateImages`.
9. Nếu ảnh không hợp lệ, app hiển thị lỗi và yêu cầu tải ảnh khác.
10. App upload ảnh lên Firebase Storage.
11. App lưu document `listings` với `status = published`, `moderationStatus = approved`.

Đánh giá: luồng hợp lý với thực tế vì lỗi được báo ngay, không làm người dùng chờ admin.

## 7. Luồng tìm bạn ở ghép

1. Người dùng nhập tiêu đề, mô tả, khu vực/ngân sách/thói quen.
2. Ảnh là tùy chọn.
3. Nếu có ảnh, app kiểm tra tối đa 10 ảnh và lọc bằng model local.
4. Text vẫn được kiểm duyệt qua Cloud Function.
5. Bài hợp lệ được lưu `published/approved`.

Điểm cần lưu ý: bài tìm bạn ở ghép hiện dùng `GeoPoint(0, 0)` trong model khi không có vị trí cụ thể. Nếu sau này cần tìm theo bán kính/bản đồ, cần thiết kế lại location cho loại bài này.

## 8. Luồng cập nhật bài

Khi cập nhật bài, app kiểm tra lại:

- Nội dung chữ qua `moderateText`.
- Ảnh mới nếu người dùng chọn ảnh mới.
- Bài cho thuê vẫn phải có ít nhất 1 ảnh sau khi cập nhật.
- Giá phòng cho thuê tối thiểu 1.000.000 VND.
- Sau khi hợp lệ, bài được cập nhật lại `published/approved`.

Rủi ro còn lại: nếu bài cũ đã có ảnh không đạt chuẩn hoặc số lượng ảnh cũ vượt giới hạn, luồng hiện tại chủ yếu kiểm tra ảnh mới. Nên bổ sung kiểm tra tổng số ảnh sau cập nhật và cơ chế migrate dữ liệu cũ.

## 9. Thiết kế kiểm duyệt

### Kiểm duyệt text

Client dùng `TextModerationService` gọi Cloud Function `moderateText` tại region `asia-southeast1`.

Backend:

- Bắt buộc user đã đăng nhập hoặc gửi ID token hợp lệ.
- Kiểm tra nhanh danh sách từ nhạy cảm tiếng Việt sau khi normalize dấu/khoảng trắng.
- Nếu không bắt được từ cấm local, gọi Hugging Face Inference Providers với model Gemma.
- Trả về `ModerationResult` gồm `passed`, `message`, `violations`, `details`.

Đánh giá: phù hợp MVP. Tuy nhiên nếu API ngoài lỗi hoặc fallback quá thoáng, nội dung xấu có thể lọt. Production nên có logging, retry, quota handling và chính sách fail-closed rõ ràng cho nội dung public.

### Kiểm duyệt ảnh

Client dùng `ImageModerationService` với TFLite model local:

- Asset: `assets/models/room_filter_model.tflite`.
- Labels: `assets/models/class_names.json`.
- Class hiện tại: `Bathroom`, `Bedroom`, `Dinning`, `Invalid`, `Kitchen`, `Livingroom`.
- Dung lượng tối đa mỗi ảnh: 5MB.
- Định dạng hợp lệ: jpg, jpeg, png, webp.
- Confidence tối thiểu: `0.60`.
- `Invalid` hoặc class ngoài nhóm phòng/không gian hợp lệ sẽ bị chặn.

Đánh giá: hướng này tiết kiệm chi phí và chạy được khi không muốn gọi API ảnh. Cần test model trên nhiều ảnh thực tế để giảm false positive/false negative.

## 10. Firebase và bảo mật

### Firestore

Collections chính:

| Collection | Mục đích |
| --- | --- |
| `users` | Hồ sơ người dùng, bài đã lưu, role |
| `listings` | Bài đăng phòng trọ/tìm bạn ở ghép |
| `listings/{listingId}/comments` | Bình luận công khai |
| `chats` | Metadata hội thoại |
| `chats/{chatId}/messages` | Tin nhắn riêng |
| `reports` | Báo cáo vi phạm |

Rules hiện tại:

- User phải đăng nhập để tạo/sửa dữ liệu chính.
- Người dùng chỉ tạo bài nếu `authorId == request.auth.uid`.
- Bài tạo/cập nhật phải có `status = published` và `moderationStatus = approved`.
- Owner hoặc admin có thể sửa/xóa bài.
- Comments chỉ được tạo nếu `status = published` và `moderationStatus = approved`.
- Chat chỉ cho participant đọc/ghi.

Rủi ro: rules hiện tin vào client khi client ghi `moderationStatus = approved`. Người dùng có thể chỉnh app/API để bỏ qua kiểm duyệt rồi ghi trạng thái approved nếu các field khác hợp lệ. Production nên chuyển bước tạo/cập nhật bài public sang Cloud Function hoặc rule kiểm tra token/kết quả moderation do server ký.

### Storage

Rules hiện tại:

- Chỉ user đăng nhập được upload.
- File phải là image và tối đa 5MB.
- `users/{userId}` chỉ chủ tài khoản được upload.
- `posts/{postId}` cho phép mọi user đăng nhập upload ảnh vào mọi `postId`.

Rủi ro: path `posts/{postId}` chưa ràng buộc owner của bài đăng. Nên đổi sang cấu trúc có `authorId` trong path hoặc dùng custom claims/Firestore get để xác thực người upload là owner của listing.

## 11. Ràng buộc dữ liệu

| Dữ liệu | Ràng buộc hiện tại | Đánh giá |
| --- | --- | --- |
| Tiêu đề | Không được rỗng, được kiểm duyệt text | Phù hợp |
| Mô tả | Không được rỗng, được kiểm duyệt text | Phù hợp |
| Giá phòng cho thuê | Tối thiểu 1.000.000 VND | Phù hợp thực tế |
| Giá tối đa | Không giới hạn | Phù hợp yêu cầu hiện tại |
| Ảnh phòng cho thuê | Bắt buộc 1-10 ảnh | Phù hợp |
| Ảnh tìm bạn ở ghép | Không bắt buộc, tối đa 10 nếu có | Phù hợp |
| Dung lượng ảnh | Tối đa 5MB/file | Phù hợp MVP |
| Định dạng ảnh | jpg, jpeg, png, webp | Phù hợp |
| Status bài hợp lệ | `published` | Phù hợp luồng không duyệt thủ công |
| Moderation bài hợp lệ | `approved` | Phù hợp nhưng cần server-side hardening |
| Chat | Không kiểm duyệt | Phù hợp yêu cầu “chỉ public mới cần kiểm duyệt” |

## 12. Mức độ hoàn thiện

| Nhóm chức năng | Mức hoàn thiện | Nhận xét |
| --- | ---: | --- |
| Authentication/Profile | 75% | Đăng nhập Google và sync user ổn, cần polish lỗi/UX |
| Đăng bài cho thuê | 80% | Validation chính đã có, cần server-side moderation |
| Tìm bạn ở ghép | 75% | Ảnh optional đúng yêu cầu, location còn đơn giản |
| Cập nhật bài | 75% | Có kiểm duyệt lại, cần kiểm tra dữ liệu cũ/tổng ảnh |
| Kiểm duyệt text | 75% | Có local filter + API, phụ thuộc provider ngoài |
| Kiểm duyệt ảnh | 75% | TFLite local chạy được, cần test model rộng hơn |
| Feed/Detail | 70% | Đủ dùng MVP, cần tối ưu query/pagination |
| Bình luận | 70% | Có kiểm duyệt text, cần rule/filter đọc comment chặt hơn nếu có trạng thái khác |
| Chat | 70% | Quyền participant cơ bản ổn |
| Firebase Rules | 65% | Có nền tảng, còn rủi ro client tự set approved |
| Storage | 60% | Check file cơ bản, còn thiếu owner constraint |
| Test/QA | 45% | Chủ yếu test thủ công, thiếu test tự động |

## 13. Lỗi/rủi ro cần fix

| Mức độ | Vấn đề | Ảnh hưởng | Hướng fix |
| --- | --- | --- | --- |
| Cao | Client tự ghi `moderationStatus = approved` | Có thể bypass kiểm duyệt bằng app/API chỉnh sửa | Tạo/update bài qua Cloud Function hoặc token kết quả server-side |
| Cao | Storage `posts/{postId}` chưa ràng buộc owner | User đăng nhập có thể upload vào path bài khác | Ràng buộc path theo `authorId` hoặc check owner qua Firestore |
| Cao | Fallback kiểm duyệt text khi API ngoài lỗi cần chính sách rõ | Có thể lọt nội dung xấu hoặc chặn nhầm | Log lỗi, cảnh báo provider, quyết định fail-open/fail-closed |
| Trung bình | Code admin/rejected cũ vẫn còn | Dễ gây hiểu nhầm nghiệp vụ và lỗi UI về sau | Dọn code legacy hoặc tách rõ là deprecated |
| Trung bình | Saved posts chỉ query tối đa 10 ID | User lưu nhiều bài sẽ không thấy hết | Chia batch query hoặc tạo subcollection savedPosts |
| Trung bình | Roommate post dùng `GeoPoint(0,0)` | Tìm kiếm theo bản đồ/bán kính không chính xác | Thiết kế location riêng cho roommate |
| Trung bình | Upload ảnh trước rồi Firestore lỗi có thể tạo ảnh mồ côi | Tốn Storage, dữ liệu rác | Cleanup ảnh nếu lưu Firestore thất bại |
| Trung bình | Thiếu test tự động cho rules/functions | Khó đảm bảo không regression | Thêm Firebase Emulator test và unit/widget tests |
| Thấp | Một số text/comment trong code bị mojibake | Ảnh hưởng maintainability/UI nếu hiển thị | Chuẩn hóa UTF-8 và rà lại copy |

## 14. Thứ tự fix đề xuất

1. Chuyển create/update listing public sang Cloud Function để server kiểm duyệt và ghi `approved`.
2. Siết Storage Rules cho ảnh bài đăng theo owner.
3. Dọn code/trạng thái legacy `pending/rejected/admin moderation` nếu không dùng nữa.
4. Bổ sung test Firebase Rules và Cloud Functions bằng Emulator.
5. Bổ sung test model ảnh với tập ảnh phòng thật/ảnh không hợp lệ.
6. Cải thiện saved posts vượt quá 10 bài.
7. Chuẩn hóa encoding tiếng Việt trong các file còn mojibake.
8. Tối ưu feed bằng pagination/index phù hợp.

## 15. Checklist test thủ công

### Auth/Profile

- Đăng nhập Google lần đầu và kiểm tra document `users/{uid}` được tạo.
- Đăng xuất/đăng nhập lại và kiểm tra profile vẫn đúng.
- User thường không sửa được `role` của chính mình.

### Đăng bài cho thuê

- Không chọn ảnh và bấm đăng: app báo cần ít nhất 1 ảnh.
- Chọn hơn 10 ảnh: app báo giới hạn ảnh.
- Nhập giá dưới 1.000.000: app báo lỗi giá tối thiểu.
- Nhập từ nhạy cảm trong tiêu đề/mô tả: app báo nội dung không phù hợp.
- Chọn ảnh không phải phòng trọ: app báo ảnh không hợp lệ.
- Đăng bài hợp lệ: Firestore lưu `published/approved`, ảnh upload Storage.

### Tìm bạn ở ghép

- Đăng không có ảnh: thành công nếu text hợp lệ.
- Đăng có ảnh không hợp lệ: app chặn.
- Nhập từ nhạy cảm: app chặn.

### Cập nhật bài

- Sửa nội dung thành vi phạm: app chặn và không update.
- Thay ảnh bằng ảnh không hợp lệ: app chặn.
- Bài cho thuê không còn ảnh: app chặn.
- Sửa hợp lệ: Firestore update `published/approved`.

### Bình luận/Chat

- Bình luận có từ nhạy cảm: app chặn.
- Bình luận hợp lệ: được lưu dưới `listings/{id}/comments`.
- Chat giữa hai participant: gửi/nhận được.
- User ngoài participant không đọc/ghi được chat bằng rules.

### Firebase Rules/Storage

- User chưa đăng nhập không tạo listing/comment/chat được.
- User A không update/delete listing của User B.
- File ảnh trên 5MB bị Storage Rules chặn.
- File không phải image bị Storage Rules chặn.

## 16. Câu hỏi cần xác nhận

| Câu hỏi | Lý do cần xác nhận |
| --- | --- |
| Có giữ role/admin cho mục đích báo cáo/quản trị sau này không? | Nếu không, nên dọn code admin legacy |
| Khi API kiểm duyệt text lỗi, app nên chặn đăng hay cho qua theo local filter? | Ảnh hưởng trực tiếp tới trải nghiệm và an toàn nội dung |
| Bài tìm bạn ở ghép có cần vị trí bản đồ chính xác không? | Hiện đang dùng location mặc định `(0,0)` |
| Có cần kiểm duyệt lại toàn bộ ảnh cũ khi cập nhật bài không? | Đảm bảo dữ liệu cũ tuân thủ rule mới |
| Có cần lưu lịch sử moderation/audit không? | Hữu ích nếu có báo cáo tranh chấp hoặc cần debug |

## 17. Kết luận nghiệp vụ

Sau khi sửa, nghiệp vụ phù hợp hơn với một ứng dụng tìm trọ thực tế:

- Nội dung public phải được kiểm duyệt trước khi xuất hiện.
- Chat riêng không kiểm duyệt là hợp lý trong phạm vi MVP.
- Bài cho thuê bắt buộc có ảnh thật giúp tăng độ tin cậy.
- Bài tìm bạn ở ghép cho phép không có ảnh là hợp lý vì trọng tâm là thông tin người ở ghép.
- Giá tối thiểu 1.000.000 VND giúp giảm spam/bài vô nghĩa trong bối cảnh phòng trọ.

Điểm quan trọng nhất cần nâng cấp tiếp theo là đưa quyết định kiểm duyệt và ghi trạng thái approved về server để tránh bị bypass từ client.

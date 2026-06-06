# Đặc tả kỹ thuật hệ thống - Room Finder Social

## Tổng quan hệ thống

**Tên ứng dụng:** Room Finder Social  
**Mô tả:** Ứng dụng tìm trọ thông minh cho sinh viên với tính năng mạng xã hội  
**Phiên bản:** 1.0.0+1  
**Nền tảng:** Flutter (iOS/Android)  
**Ngôn ngữ:** Dart  

## Kiến trúc hệ thống

### 1. Kiến trúc tổng thể
- **Frontend:** Flutter với Material Design 3
- **Backend:** Firebase (Firestore, Auth, Storage)
- **Maps:** Google Maps Flutter
- **State Management:** Riverpod (có sẵn trong pubspec nhưng chưa sử dụng)
- **Navigation:** Go Router (có sẵn nhưng chưa sử dụng, hiện tại dùng BottomNavigationBar)

### 2. Cấu trúc thư mục
```
lib/
├── main.dart                    # Entry point, Firebase init
├── firebase_options.dart        # Firebase config
├── core/                        # Core utilities (chưa có)
├── data/
│   ├── models/
│   │   ├── listing_model.dart   # Model cho bài đăng phòng
│   │   └── user_model.dart      # Model cho user
│   └── services/
│       ├── auth_service.dart    # Firebase Auth service
│       └── post_service.dart    # CRUD cho listings
└── presentation/
    └── pages/                   # UI pages
```

## Models dữ liệu

### 1. ListingModel
```dart
enum ListingStatus { pending, published, rejected, closed }
enum PostType { roomForRent, roommateWanted }

class ListingModel {
  final String id;
  final String authorId;
  final PostType postType;
  final String title;
  final String description;
  final double price;
  final ListingStatus status;
  final GeoPoint location;
  final String address;
  final List<String> mediaUrls;
  final DateTime createdAt;
  final String? moderationComment;
  final Map<String, bool> amenities;

  // Cost estimation fields
  final double electricPrice;
  final double waterPrice;
  final double serviceFee;
  final double otherFee;
  final double defaultElectricUsage;
  final double defaultWaterUsage;
}
```

### 2. UserModel
```dart
class UserModel {
  final String uid;
  final String email;
  final String displayName;
  final String? avatarUrl;
  final String? phoneNumber;
  final String role; // 'user' hoặc 'admin'
  final List<String> habitTags;
  final List<String> savedPostIds;
  final DateTime createdAt;

  // Personalization fields
  final double budgetMin;
  final double budgetMax;
  final List<String> preferredAreas;
}
```

## Services

### 1. AuthService
- **Chức năng:** Xử lý authentication với Google Sign-In
- **Methods chính:**
  - `signInWithGoogle()`: Đăng nhập Google
  - `getUserData(uid)`: Lấy thông tin user từ Firestore
  - `syncUserToFirestore(user)`: Đồng bộ user data
  - `userStream`: Stream<User?> cho auth state

### 2. PostService
- **Chức năng:** CRUD operations cho listings
- **Methods chính:**
  - `createPost(post)`: Tạo bài đăng mới
  - `toggleSavePost(userId, postId, isSaved)`: Lưu/bỏ lưu bài đăng
  - `getSavedPosts(savedIds)`: Lấy danh sách bài đã lưu

## UI Architecture

### 1. Navigation Structure
```
AuthWrapper (StreamBuilder)
├── LoginPage (nếu chưa đăng nhập)
└── MainScreen (nếu đã đăng nhập)
    ├── HomePage (Tab 0)
    ├── ExplorePage (Tab 1)
    ├── PostChoicePage (Tab 2)
    ├── ChatListPage (Tab 3)
    └── ProfilePage (Tab 4)
```

### 2. Main Pages

#### HomePage
- **Chức năng:** Feed bài đăng đã publish
- **Components:** StreamBuilder cho listings, PostCard
- **Tương tác:** Tap search bar → navigate to Explore tab

#### ExplorePage
- **Chức năng:** Tìm kiếm và khám phá listings
- **Features:**
  - Toggle Map/List view
  - Cost filter (RangeSlider)
  - Search functionality
- **Components:** ToggleButtons, MapExplorerPage, filter sheet

#### PostChoicePage
- **Chức năng:** Chọn loại bài đăng (Phòng trọ / Tìm bạn ở ghép)
- **Navigation:** Navigate to CreatePostPage hoặc RoommatePostPage

#### ChatListPage
- **Chức năng:** Danh sách cuộc trò chuyện
- **Components:** StreamBuilder cho chats

#### ProfilePage
- **Chức năng:** Profile user với posts và settings
- **Components:** StreamBuilder cho user data, menu items

### 3. Secondary Pages

#### LoginPage
- **Chức năng:** Đăng nhập Google
- **Components:** Google Sign-In button

#### CreatePostPage
- **Chức năng:** Form tạo bài đăng phòng trọ
- **Features:** Media upload, location picker, preview

#### RoommatePostPage
- **Chức năng:** Form tìm bạn ở ghép
- **Features:** Habit tags, preferred areas, budget range

#### PostDetailPage
- **Chức năng:** Chi tiết bài đăng
- **Features:** Save/unsave, contact author, view on map

#### ChatDetailPage
- **Chức năng:** Chat interface
- **Features:** Post shortcut (nếu chat có liên kết post)

#### UserProfilePage
- **Chức năng:** Xem profile của user khác
- **Components:** User info, their posts list

#### SettingsPage
- **Chức năng:** Cài đặt ứng dụng
- **Menu items:** Thông báo, Riêng tư, Trợ giúp, Đăng xuất

#### PostPreviewPage
- **Chức năng:** Preview bài đăng trước khi submit

## Firebase Structure

### 1. Collections

#### users
```json
{
  "uid": "string",
  "email": "string",
  "displayName": "string",
  "avatarUrl": "string?",
  "phoneNumber": "string?",
  "role": "user|admin",
  "habitTags": ["string"],
  "savedPostIds": ["string"],
  "budgetMin": number,
  "budgetMax": number,
  "preferredAreas": ["string"],
  "createdAt": timestamp
}
```

#### listings
```json
{
  "id": "string",
  "authorId": "string",
  "postType": "roomForRent|roommateWanted",
  "title": "string",
  "description": "string",
  "price": number,
  "status": "pending|published|rejected|closed",
  "location": GeoPoint,
  "address": "string",
  "mediaUrls": ["string"],
  "createdAt": timestamp,
  "moderationComment": "string?",
  "amenities": {"key": boolean},
  "electricPrice": number,
  "waterPrice": number,
  "serviceFee": number,
  "otherFee": number,
  "defaultElectricUsage": number,
  "defaultWaterUsage": number
}
```

#### chats (assumed structure)
```json
{
  "id": "string",
  "participants": ["uid1", "uid2"],
  "lastMessage": "string",
  "lastMessageTime": timestamp,
  "postId": "string?" // for post-linked chats
}
```

### 2. Storage
- **Bucket:** Media files cho listings (images/videos)
- **Structure:** `/listings/{listingId}/{filename}`

## Dependencies & Libraries

### Core Dependencies
- **Firebase:** firebase_core, firebase_auth, cloud_firestore, firebase_storage
- **Google Services:** google_sign_in
- **Maps:** google_maps_flutter, geoflutterfire2, geolocator, geocoding
- **Media:** image_picker, video_player, flutter_image_compress, cached_network_image, photo_view
- **State/Navigation:** flutter_riverpod, go_router
- **UI:** flutter_svg, shimmer
- **Utils:** intl, shared_preferences, uuid

### Dev Dependencies
- flutter_test, flutter_lints

## Security & Permissions

### Firebase Rules (assumed)
- Users can read/write their own data
- Listings: authenticated users can create, only admins can moderate
- Storage: authenticated users can upload to their listings

### App Permissions
- Location (for maps and posting)
- Camera/Gallery (for media upload)
- Notifications (future feature)

## Current Implementation Status

### Completed Features
- [x] Firebase authentication với Google Sign-In
- [x] Core 5-tab navigation với IndexedStack
- [x] Listing creation với media upload
- [x] Real-time listings feed
- [x] Map exploration với Google Maps
- [x] Save/unsave functionality
- [x] User profiles với posts
- [x] Chat system (basic)
- [x] Settings page (basic)
- [x] Post preview
- [x] Roommate posting form
- [x] Cost estimation và filtering
- [x] Map/List toggle in explore

### Partially Implemented
- [ ] Notification settings (TODO placeholders)
- [ ] Privacy settings (TODO placeholders)
- [ ] Chat post linking (needs postId in chat documents)

### Missing Features
- [ ] Admin moderation UI
- [ ] Advanced search filters
- [ ] Push notifications
- [ ] In-app messaging improvements
- [ ] User onboarding flow

## Performance Considerations

### Real-time Updates
- Sử dụng StreamBuilder cho auth state và listings
- Firestore real-time listeners cho live data

### Image Optimization
- flutter_image_compress cho upload
- cached_network_image cho display
- photo_view cho zoom functionality

### State Management
- IndexedStack giữ state của tabs
- StreamBuilder cho reactive UI

## Future Enhancements

### High Priority
1. **Notification System:** Push notifications cho new messages/posts
2. **Advanced Search:** Full-text search, filters nâng cao
3. **Admin Panel:** UI cho moderation

### Medium Priority
4. **User Onboarding:** Tutorial và setup preferences
5. **Offline Support:** Cache data cho offline viewing
6. **Analytics:** User behavior tracking

### Low Priority
7. **Social Features:** Like/comment system
8. **Premium Features:** Featured listings, priority support
9. **Multi-language:** Localization support

---

**Ngày tạo:** $(date)  
**Version:** 1.0.0  
**Author:** AI Assistant</content>
<parameter name="filePath">c:\Users\Owner\Downloads\BACH_NGOC_VY\TAI_LIEU\MON HOC HK6\Mobile\do_an\proj_code\room_finder\TECHNICAL_SPECIFICATION.md
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../data/models/listing_model.dart';
import '../../data/services/location_service.dart';
import '../../features/user/presentation/pages/notifications_page.dart';
import '../widgets/post_card.dart';
import 'main_screen.dart';
import 'post_detail_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final LocationService _locationService = LocationService();

  Position? _currentPosition;
  bool _isLoadingLocation = true;

  @override
  void initState() {
    super.initState();
    _loadCurrentPosition();
  }

  Future<void> _loadCurrentPosition() async {
    final position = await _locationService.getCurrentPosition();
    if (!mounted) return;

    setState(() {
      _currentPosition = position;
      _isLoadingLocation = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Room Finder',
          style: TextStyle(
            color: Colors.blue,
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        actions: const [_NotificationButton()],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('listings')
            .where('status', isEqualTo: 'published')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Lỗi: ${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final posts = snapshot.data!.docs
              .map(
                (doc) => ListingModel.fromMap(
                  doc.data() as Map<String, dynamic>,
                  doc.id,
                ),
              )
              .toList();

          if (posts.isEmpty) {
            return Column(
              children: [
                _buildSearchShortcut(context),
                const Expanded(
                  child: Center(child: Text('Chưa có bài đăng nào.')),
                ),
              ],
            );
          }

          final recommendations = _rankRecommendations(posts).take(5).toList();

          return RefreshIndicator(
            onRefresh: _loadCurrentPosition,
            child: ListView(
              padding: const EdgeInsets.only(top: 8, bottom: 20),
              children: [
                _buildSearchShortcut(context),
                if (recommendations.isNotEmpty)
                  _RecommendationSection(
                    recommendations: recommendations,
                    isLoadingLocation: _isLoadingLocation,
                    hasLocation: _currentPosition != null,
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: Text(
                    'Bài đăng mới nhất',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                ...posts.map((post) => PostCard(post: post)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSearchShortcut(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: () => MainScreen.of(context)?.setTab(1),
        borderRadius: BorderRadius.circular(30),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.grey[200]!),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: const Row(
            children: [
              Icon(Icons.search, color: Colors.grey),
              SizedBox(width: 10),
              Text(
                'Tìm kiếm phòng, khu vực...',
                style: TextStyle(color: Colors.grey),
              ),
              Spacer(),
              Icon(Icons.tune, color: Colors.blue),
            ],
          ),
        ),
      ),
    );
  }

  List<_ScoredListing> _rankRecommendations(List<ListingModel> posts) {
    final prices = posts.map((post) => post.estimatedMonthlyCost).toList();
    final distances = posts.map(_distanceInMeters).toList();
    final validDistances = distances.whereType<double>().toList();

    final minPrice = prices.reduce((a, b) => a < b ? a : b);
    final maxPrice = prices.reduce((a, b) => a > b ? a : b);
    final minDistance = validDistances.isEmpty
        ? 0.0
        : validDistances.reduce((a, b) => a < b ? a : b);
    final maxDistance = validDistances.isEmpty
        ? 0.0
        : validDistances.reduce((a, b) => a > b ? a : b);

    final scored = <_ScoredListing>[];
    for (var i = 0; i < posts.length; i++) {
      final post = posts[i];
      final priceScore = _normalize(
        post.estimatedMonthlyCost,
        minPrice,
        maxPrice,
      );
      final distance = distances[i];
      final distanceScore = distance == null
          ? 1.0
          : _normalize(distance, minDistance, maxDistance);
      final score = 0.6 * priceScore + 0.4 * distanceScore;

      scored.add(
        _ScoredListing(
          post: post,
          score: score,
          distanceInMeters: distance,
        ),
      );
    }

    scored.sort((a, b) => a.score.compareTo(b.score));
    return scored;
  }

  double? _distanceInMeters(ListingModel post) {
    final position = _currentPosition;
    final location = post.location;
    if (position == null) return null;
    if (location.latitude == 0 && location.longitude == 0) return null;

    return _locationService.distanceInMeters(
      position.latitude,
      position.longitude,
      location.latitude,
      location.longitude,
    );
  }

  double _normalize(double value, double min, double max) {
    if (max <= min) return 0;
    return ((value - min) / (max - min)).clamp(0.0, 1.0).toDouble();
  }
}

class _RecommendationSection extends StatelessWidget {
  final List<_ScoredListing> recommendations;
  final bool isLoadingLocation;
  final bool hasLocation;

  const _RecommendationSection({
    required this.recommendations,
    required this.isLoadingLocation,
    required this.hasLocation,
  });

  @override
  Widget build(BuildContext context) {
    final subtitle = isLoadingLocation
        ? 'Đang lấy vị trí để tính khoảng cách...'
        : hasLocation
            ? 'Gọi ý dựa trên giá ước tính + và khoảng cách'
            : 'Chưa có vị trí, tạm ưu tiên theo giá ước tính';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Row(
            children: [
              const Icon(Icons.auto_awesome, color: Colors.blue, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Gợi ý phù hợp',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            subtitle,
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 124,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemBuilder: (context, index) {
              return _RecommendationCard(item: recommendations[index]);
            },
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemCount: recommendations.length,
          ),
        ),
      ],
    );
  }
}

class _RecommendationCard extends StatelessWidget {
  final _ScoredListing item;

  const _RecommendationCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final post = item.post;
    final distanceText = item.distanceInMeters == null
        ? 'Chưa có khoảng cách'
        : item.distanceInMeters! >= 1000
            ? '${(item.distanceInMeters! / 1000).toStringAsFixed(1)} km'
            : '${item.distanceInMeters!.round()} m';

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => PostDetailPage(post: post)),
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 246,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.blue.withOpacity(0.12)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 74,
                height: 96,
                color: Colors.grey[200],
                child: post.mediaUrls.isEmpty
                    ? const Icon(Icons.home_outlined, color: Colors.grey)
                    : Image.network(post.mediaUrls.first, fit: BoxFit.cover),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    post.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '~ ${_formatCompactPrice(post.estimatedMonthlyCost)}/tháng',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.blue[800],
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.place_outlined,
                        color: Colors.grey,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          distanceText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Điểm ${(item.score * 100).toStringAsFixed(0)}',
                    style: const TextStyle(color: Colors.grey, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatCompactPrice(double value) {
    if (value >= 1000000) {
      final million = value / 1000000;
      return '${million.toStringAsFixed(million >= 10 ? 0 : 1)}tr';
    }
    return '${value.round()}đ';
  }
}

class _ScoredListing {
  final ListingModel post;
  final double score;
  final double? distanceInMeters;

  const _ScoredListing({
    required this.post,
    required this.score,
    required this.distanceInMeters,
  });
}

class _NotificationButton extends StatelessWidget {
  const _NotificationButton();

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return StreamBuilder<QuerySnapshot>(
      stream: user == null
          ? null
          : FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('notifications')
              .where('read', isEqualTo: false)
              .snapshots(),
      builder: (context, snapshot) {
        final unreadCount = snapshot.data?.docs.length ?? 0;
        return Stack(
          alignment: Alignment.center,
          children: [
            IconButton(
              icon: const Icon(
                Icons.notifications_none_outlined,
                color: Colors.black,
              ),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NotificationsPage()),
              ),
            ),
            if (unreadCount > 0)
              Positioned(
                right: 10,
                top: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 16,
                    minHeight: 16,
                  ),
                  child: Text(
                    unreadCount > 9 ? '9+' : '$unreadCount',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

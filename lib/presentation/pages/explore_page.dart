import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../data/models/listing_model.dart';
import '../../data/models/user_model.dart';
import '../../data/services/location_service.dart';
import '../../data/services/user_service.dart';
import '../widgets/post_card.dart';
import '../widgets/roommate_card.dart';
import 'user_profile_page.dart';

class ExplorePage extends StatefulWidget {
  const ExplorePage({super.key});

  @override
  State<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends State<ExplorePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final UserService _userService = UserService();
  final LocationService _locationService = LocationService();
  final _currentUser = FirebaseAuth.instance.currentUser;

  String _searchQuery = '';
  GeoPoint? _searchLocation;
  Timer? _searchDebounce;
  RangeValues _priceRange = const RangeValues(0, 20000000);
  String _selectedRoomType = 'Tất cả';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    setState(() {
      _searchQuery = value.trim().toLowerCase();
      if (_searchQuery.isEmpty) _searchLocation = null;
    });

    _searchDebounce?.cancel();
    if (_searchQuery.length < 3) return;
    _searchDebounce =
        Timer(const Duration(milliseconds: 600), _geocodeSearchQuery);
  }

  Future<void> _geocodeSearchQuery() async {
    final query = _searchQuery.trim();
    if (query.length < 3) return;
    try {
      final resolved = await _locationService.searchAddress(query);
      if (resolved == null || !mounted) return;
      setState(() => _searchLocation = resolved.point);
    } catch (_) {
      if (mounted) setState(() => _searchLocation = null);
    }
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Bộ lọc nâng cao',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              const Text('Tổng chi phí ước tính (VNĐ)',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              RangeSlider(
                values: _priceRange,
                min: 0,
                max: 20000000,
                divisions: 20,
                labels: RangeLabels('${_priceRange.start.toInt()}',
                    '${_priceRange.end.toInt()}'),
                onChanged: (val) {
                  setSheetState(() => _priceRange = val);
                  setState(() {});
                },
              ),
              const SizedBox(height: 16),
              const Text('Loại phòng',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              Wrap(
                spacing: 8,
                children: ['Tất cả', 'Phòng đơn', 'Chung cư', 'Nhà nguyên căn']
                    .map((type) {
                  return ChoiceChip(
                    label: Text(type),
                    selected: _selectedRoomType == type,
                    onSelected: (selected) {
                      setSheetState(() => _selectedRoomType = type);
                      setState(() {});
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50)),
                child: const Text('ÁP DỤNG'),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: _buildSearchField(),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterSheet,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.blue[800],
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.blue[800],
          tabs: const [
            Tab(text: 'Phòng trọ'),
            Tab(text: 'Tìm bạn ở ghép'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildRoomSearchTab(),
          _buildRoommateMatchingTab(),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return Container(
      height: 45,
      decoration: BoxDecoration(
          color: Colors.grey[100], borderRadius: BorderRadius.circular(12)),
      child: TextField(
        onChanged: _onSearchChanged,
        onSubmitted: (_) => _geocodeSearchQuery(),
        decoration: InputDecoration(
          hintText: 'Khu vực, tên phòng...',
          prefixIcon: const Icon(Icons.search, size: 20),
          suffixIcon: IconButton(
              icon: const Icon(Icons.tune, size: 20),
              onPressed: _showFilterSheet),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
        ),
      ),
    );
  }

  Widget _buildRoomSearchTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Lọc theo giá', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(
                    '${_formatPrice(_priceRange.start)} – ${_formatPrice(_priceRange.end)}',
                    style: TextStyle(color: Colors.blue[800], fontSize: 13),
                  ),
                ],
              ),
              RangeSlider(
                values: _priceRange,
                min: 0,
                max: 20000000,
                divisions: 20,
                onChanged: (val) => setState(() => _priceRange = val),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('listings')
                .where('status', isEqualTo: 'published')
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData)
                return const Center(child: CircularProgressIndicator());

              final posts = snapshot.data!.docs
                  .map((doc) => ListingModel.fromMap(
                  doc.data() as Map<String, dynamic>, doc.id))
                  .where((post) {
                final normalizedQuery = _searchQuery.trim().toLowerCase();
                final searchableText = [
                  post.title, post.address, post.description,
                  post.postType == PostType.roomForRent ? 'phòng trọ cho thuê' : 'tìm bạn ở ghép',
                ].join(' ').toLowerCase();
                final matchText = normalizedQuery.isEmpty || searchableText.contains(normalizedQuery);
                final matchLocation = _searchLocation == null
                    ? false
                    : Geolocator.distanceBetween(
                  _searchLocation!.latitude, _searchLocation!.longitude,
                  post.location.latitude, post.location.longitude,
                ) <= 7000;
                final matchSearch = normalizedQuery.isEmpty || matchText || matchLocation;
                final matchPrice = post.price >= _priceRange.start && post.price <= _priceRange.end;
                return matchSearch && matchPrice;
              }).toList();

              if (posts.isEmpty)
                return const Center(child: Text('Không tìm thấy kết quả phù hợp.'));

              return ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: posts.length,
                itemBuilder: (context, index) => PostCard(post: posts[index]),
              );
            },
          ),
        ),
      ],
    );
  }

  String _formatPrice(double value) {
    if (value >= 1000000) {
      final m = value / 1000000;
      return '${m.toStringAsFixed(m >= 10 ? 0 : 1)}tr';
    }
    return '${value.round()}đ';
  }

  Widget _buildRoommateMatchingTab() {
    if (_currentUser == null)
      return const Center(child: Text('Vui lòng đăng nhập'));

    return StreamBuilder<List<UserModel>>(
      stream: _userService.getPotentialRoommates(_currentUser!.uid),
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());

        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(_currentUser!.uid)
              .snapshots(),
          builder: (context, currentSnap) {
            if (!currentSnap.hasData) return const SizedBox();
            if (currentSnap.data?.data() == null) {
              return const Center(
                  child: Text('Vui lòng cập nhật hồ sơ để tìm bạn ở ghép'));
            }

            final currentUserModel = UserModel.fromMap(
                currentSnap.data!.data() as Map<String, dynamic>,
                _currentUser!.uid);
            // Filter by search query, then compute match percentage,
            // sort by score descending and limit to top 10 results.
            final filtered = snapshot.data!.where((u) {
              if (_searchQuery.isEmpty) return true;
              final searchableText = [
                u.displayName,
                u.preferredAreas.join(' '),
                u.habitTags.join(' '),
              ].join(' ').toLowerCase();
              return searchableText.contains(_searchQuery);
            }).toList();

            final scored = filtered
                .map((u) => MapEntry(u,
                    _userService.calculateMatchPercentage(currentUserModel, u)))
                .toList();

            scored.sort((a, b) => b.value.compareTo(a.value));

            // limit to top 10
            final top = scored.take(10).toList();

            if (top.isEmpty) {
              return const Center(child: Text('Không tìm thấy người phù hợp.'));
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: top.length,
              itemBuilder: (context, index) {
                final otherUser = top[index].key;
                final matchPercent = top[index].value;
                return RoommateCard(
                  user: otherUser,
                  matchPercentage: matchPercent,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => UserProfilePage(userId: otherUser.uid)),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

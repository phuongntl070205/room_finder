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
  bool _isFilterApplied = false;

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

  String _formatMoney(double value) {
    final text = value.toInt().toString();
    final buffer = StringBuffer();

    for (int i = 0; i < text.length; i++) {
      final indexFromEnd = text.length - i;
      buffer.write(text[i]);
      if (indexFromEnd > 1 && indexFromEnd % 3 == 1) {
        buffer.write('.');
      }
    }

    return '${buffer.toString()} đ';
  }

  void _onSearchChanged(String value) {
    setState(() {
      _searchQuery = value.trim().toLowerCase();
      if (_searchQuery.isEmpty) _searchLocation = null;
    });

    _searchDebounce?.cancel();

    if (_searchQuery.length < 3) return;

    _searchDebounce = Timer(
      const Duration(milliseconds: 600),
      _geocodeSearchQuery,
    );
  }

  Future<void> _geocodeSearchQuery() async {
    final query = _searchQuery.trim();

    if (query.length < 3) return;

    try {
      final resolved = await _locationService.searchAddress(query);

      if (resolved == null || !mounted) return;

      setState(() {
        _searchLocation = resolved.point;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _searchLocation = null;
        });
      }
    }
  }

  void _showFilterSheet() {
    RangeValues tempPriceRange = _priceRange;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(20),
        ),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Bộ lọc nâng cao',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 24),

                  const Text(
                    'Khoảng giá / ngân sách (VNĐ)',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 8),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatMoney(tempPriceRange.start),
                        style: const TextStyle(
                          color: Colors.blue,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        _formatMoney(tempPriceRange.end),
                        style: const TextStyle(
                          color: Colors.blue,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),

                  RangeSlider(
                    values: tempPriceRange,
                    min: 0,
                    max: 20000000,
                    divisions: 40,
                    labels: RangeLabels(
                      _formatMoney(tempPriceRange.start),
                      _formatMoney(tempPriceRange.end),
                    ),
                    onChanged: (value) {
                      setSheetState(() {
                        tempPriceRange = value;
                      });
                    },
                  ),

                  const SizedBox(height: 32),

                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            setState(() {
                              _priceRange = const RangeValues(0, 20000000);
                              _isFilterApplied = false;
                            });

                            Navigator.pop(context);
                          },
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 50),
                          ),
                          child: const Text('ĐẶT LẠI'),
                        ),
                      ),

                      const SizedBox(width: 12),

                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _priceRange = tempPriceRange;
                              _isFilterApplied = true;
                            });

                            Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 50),
                          ),
                          child: const Text('ÁP DỤNG'),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            );
          },
        );
      },
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
            icon: const Icon(Icons.list),
            onPressed: () {},
          ),
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
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        onChanged: _onSearchChanged,
        onSubmitted: (_) => _geocodeSearchQuery(),
        decoration: const InputDecoration(
          hintText: 'Khu vực, tên phòng...',
          prefixIcon: Icon(Icons.search, size: 20),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: 10),
        ),
      ),
    );
  }

  Widget _buildRoomSearchTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('listings')
          .where('status', isEqualTo: 'published')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        final posts = snapshot.data!.docs
            .map(
              (doc) => ListingModel.fromMap(
            doc.data() as Map<String, dynamic>,
            doc.id,
          ),
        )
            .where((post) {
          final normalizedQuery = _searchQuery.trim().toLowerCase();

          final searchableText = [
            post.title,
            post.address,
            post.description,
            post.postType == PostType.roomForRent
                ? 'phòng trọ cho thuê'
                : 'tìm bạn ở ghép',
          ].join(' ').toLowerCase();

          final matchText = normalizedQuery.isEmpty ||
              searchableText.contains(normalizedQuery);

          final matchLocation = _searchLocation == null
              ? false
              : Geolocator.distanceBetween(
            _searchLocation!.latitude,
            _searchLocation!.longitude,
            post.location.latitude,
            post.location.longitude,
          ) <=
              7000;

          final matchSearch =
              normalizedQuery.isEmpty || matchText || matchLocation;

          final matchPrice =
              post.price >= _priceRange.start && post.price <= _priceRange.end;

          return matchSearch && matchPrice;
        }).toList();

        if (posts.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                _isFilterApplied
                    ? 'Không có phòng phù hợp với khoảng giá đã chọn.'
                    : 'Không tìm thấy kết quả phù hợp.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: posts.length,
          itemBuilder: (context, index) {
            return PostCard(post: posts[index]);
          },
        );
      },
    );
  }

  Widget _buildRoommateMatchingTab() {
    if (_currentUser == null) {
      return const Center(
        child: Text('Vui lòng đăng nhập'),
      );
    }

    return StreamBuilder<List<UserModel>>(
      stream: _userService.getPotentialRoommates(_currentUser!.uid),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(_currentUser!.uid)
              .snapshots(),
          builder: (context, currentSnap) {
            if (!currentSnap.hasData) {
              return const SizedBox();
            }

            if (currentSnap.data?.data() == null) {
              return const Center(
                child: Text('Vui lòng cập nhật hồ sơ để tìm bạn ở ghép'),
              );
            }

            final currentUserModel = UserModel.fromMap(
              currentSnap.data!.data() as Map<String, dynamic>,
              _currentUser!.uid,
            );

            final otherUsers = snapshot.data!.where((u) {
              final normalizedQuery = _searchQuery.trim().toLowerCase();

              final searchableText = [
                u.displayName,
                u.preferredAreas.join(' '),
                u.habitTags.join(' '),
              ].join(' ').toLowerCase();

              final matchSearch = normalizedQuery.isEmpty ||
                  searchableText.contains(normalizedQuery);

              final matchBudget =
                  u.budgetMin <= _priceRange.end &&
                      u.budgetMax >= _priceRange.start;

              return matchSearch && matchBudget;
            }).toList();

            if (otherUsers.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    _isFilterApplied
                        ? 'Không có bạn ở ghép phù hợp với khoảng ngân sách đã chọn.'
                        : 'Không tìm thấy bạn ở ghép phù hợp.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: otherUsers.length,
              itemBuilder: (context, index) {
                final otherUser = otherUsers[index];

                final matchPercent = _userService.calculateMatchPercentage(
                  currentUserModel,
                  otherUser,
                );

                return RoommateCard(
                  user: otherUser,
                  matchPercentage: matchPercent,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => UserProfilePage(
                          userId: otherUser.uid,
                        ),
                      ),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}
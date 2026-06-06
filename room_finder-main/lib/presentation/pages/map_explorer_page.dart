import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../data/models/listing_model.dart';
import '../../data/services/location_service.dart';
import '../widgets/post_card.dart';
import '../../core/config/google_maps_config.dart';

class MapExplorerPage extends StatefulWidget {
  final String searchQuery;
  final GeoPoint? searchLocation;

  const MapExplorerPage({
    super.key,
    this.searchQuery = '',
    this.searchLocation,
  });

  @override
  State<MapExplorerPage> createState() => _MapExplorerPageState();
}

class _MapExplorerPageState extends State<MapExplorerPage> {
  static const _defaultCenter = LatLng(10.762622, 106.660172);

  final _mapController = MapController();
  final _locationService = LocationService();
  final _searchController = TextEditingController();
  Position? _currentPosition;
  LatLng _center = _defaultCenter;
  GeoPoint? _localSearchLocation;
  ListingModel? _selectedPost;
  bool _isSearching = false;
  double _radiusKm = 2.0;

  GeoPoint? get _activeSearchLocation =>
      _localSearchLocation ?? widget.searchLocation;

  String get _activeSearchQuery =>
      _searchController.text.trim().isNotEmpty
          ? _searchController.text.trim().toLowerCase()
          : widget.searchQuery.trim().toLowerCase();

  @override
  void initState() {
    super.initState();
    _searchController.text = widget.searchQuery;
    _determinePosition();
  }

  @override
  void dispose() {
    _mapController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant MapExplorerPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.searchQuery != widget.searchQuery &&
        _searchController.text != widget.searchQuery) {
      _searchController.text = widget.searchQuery;
    }
    final location = widget.searchLocation;
    if (location != null && oldWidget.searchLocation != location) {
      final target = LatLng(location.latitude, location.longitude);
      setState(() => _center = target);
      _mapController.move(target, 14);
    }
  }

  Future<void> _determinePosition() async {
    final position = await _locationService.getCurrentPosition();
    if (position == null || !mounted) return;
    final target = LatLng(position.latitude, position.longitude);
    setState(() {
      _currentPosition = position;
      _center = target;
      _localSearchLocation = GeoPoint(target.latitude, target.longitude);
      _selectedPost = null;
    });
    _mapController.move(target, 14);
  }

  Future<void> _searchLocation() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      setState(() { _localSearchLocation = null; _selectedPost = null; });
      return;
    }
    setState(() => _isSearching = true);
    try {
      final resolved = await _locationService.searchAddress(query);
      if (resolved == null || !mounted) return;
      final target = LatLng(resolved.point.latitude, resolved.point.longitude);
      setState(() {
        _localSearchLocation = resolved.point;
        _center = target;
        _selectedPost = null;
      });
      _mapController.move(target, 14);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Không tìm thấy vị trí: $e')));
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  double? _distanceToPost(ListingModel post) {
    final position = _currentPosition;
    if (position == null) return null;
    return _locationService.distanceInMeters(
      position.latitude, position.longitude,
      post.location.latitude, post.location.longitude,
    );
  }

  double _distanceFromCenter(ListingModel post) {
    return _locationService.distanceInMeters(
      _center.latitude, _center.longitude,
      post.location.latitude, post.location.longitude,
    );
  }

  bool _matchesSearch(ListingModel post) {
    final query = _activeSearchQuery;
    final searchLocation = _activeSearchLocation;
    final searchableText = [post.title, post.address, post.description]
        .join(' ').toLowerCase();
    final radiusCenter =
        searchLocation ?? GeoPoint(_center.latitude, _center.longitude);
    final radiusMatch = _locationService.distanceInMeters(
      radiusCenter.latitude, radiusCenter.longitude,
      post.location.latitude, post.location.longitude,
    ) <= _radiusKm * 1000;
    if (query.isEmpty && searchLocation == null) return radiusMatch;
    final textMatch = query.isNotEmpty && searchableText.contains(query);
    return textMatch || radiusMatch;
  }

  Future<void> _openDirections(ListingModel post) async {
    final uri = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=${post.location.latitude},${post.location.longitude}');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không thể mở chỉ đường')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: '₫');

    return Scaffold(
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('listings')
            .where('status', isEqualTo: 'published')
            .snapshots(),
        builder: (context, snapshot) {
          final posts = (snapshot.data?.docs ?? [])
              .map((doc) => ListingModel.fromMap(
              doc.data() as Map<String, dynamic>, doc.id))
              .where((post) =>
          post.location.latitude != 0 || post.location.longitude != 0)
              .where(_matchesSearch)
              .toList()
            ..sort((a, b) =>
                _distanceFromCenter(a).compareTo(_distanceFromCenter(b)));

          return Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _center,
                  initialZoom: 13,
                  onPositionChanged: (position, hasGesture) {
                    if (hasGesture && position.center != null) {
                      setState(() => _center = position.center!);
                    }
                  },
                  onTap: (_, __) {
                    if (_selectedPost != null) {
                      setState(() => _selectedPost = null);
                    }
                  },
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                    'https://api.mapbox.com/styles/v1/{styleId}/tiles/{z}/{x}/{y}?access_token={accessToken}',
                    additionalOptions: {
                      'accessToken': MapConfig.mapboxAccessToken,
                      'styleId': MapConfig.mapboxStyleId,
                    },
                  ),
                  MarkerLayer(
                    markers: posts.map((post) {
                      final isSelected = _selectedPost?.id == post.id;
                      return Marker(
                        point: LatLng(
                            post.location.latitude, post.location.longitude),
                        width: isSelected ? 48 : 40,
                        height: isSelected ? 48 : 40,
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedPost = post),
                          child: Icon(
                            Icons.location_pin,
                            color: isSelected ? Colors.blue : Colors.red,
                            size: isSelected ? 48 : 40,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),

              // Search bar
              Positioned(
                top: MediaQuery.of(context).padding.top + 8,
                left: 12, right: 12,
                child: Material(
                  elevation: 2,
                  borderRadius: BorderRadius.circular(12),
                  child: TextField(
                    controller: _searchController,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _searchLocation(),
                    decoration: InputDecoration(
                      hintText: 'Tìm vị trí, quận/huyện, địa danh...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _isSearching
                          ? const Padding(
                        padding: EdgeInsets.all(14),
                        child: SizedBox(
                          width: 16, height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                          : IconButton(
                        icon: const Icon(Icons.arrow_forward),
                        onPressed: _searchLocation,
                      ),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                ),
              ),

              // Radius slider
              Positioned(
                bottom: _selectedPost != null ? 260 : 24,
                left: 12, right: 12,
                child: _buildRadiusSlider(),
              ),

              // GPS button
              Positioned(
                bottom: _selectedPost != null ? 326 : 92,
                right: 12,
                child: FloatingActionButton.small(
                  heroTag: 'map-explorer-gps',
                  onPressed: _determinePosition,
                  child: const Icon(Icons.my_location),
                ),
              ),

              if (snapshot.connectionState == ConnectionState.waiting)
                const Positioned.fill(
                    child: Center(child: CircularProgressIndicator())),

              if (_selectedPost != null)
                Positioned(
                  bottom: 12, left: 0, right: 0,
                  child: _SelectedPostPanel(
                    post: _selectedPost!,
                    distanceMeters: _distanceToPost(_selectedPost!),
                    onDirections: () => _openDirections(_selectedPost!),
                    onClose: () => setState(() => _selectedPost = null),
                  ),
                )
              else if (posts.isEmpty &&
                  snapshot.connectionState != ConnectionState.waiting)
                Positioned(
                  bottom: 104, left: 16, right: 16,
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        _activeSearchQuery.isEmpty
                            ? 'Chưa có bài đăng có vị trí hợp lệ.'
                            : 'Không tìm thấy bài đăng quanh khu vực này.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildRadiusSlider() {
    return Material(
      elevation: 2,
      borderRadius: BorderRadius.circular(12),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Row(
          children: [
            const Icon(Icons.radar, size: 18, color: Colors.grey),
            Expanded(
              child: Slider(
                value: _radiusKm,
                min: 0.5, max: 10, divisions: 19,
                label: '${_radiusKm.toStringAsFixed(1)} km',
                onChanged: (value) => setState(() {
                  _radiusKm = value;
                  _selectedPost = null;
                }),
              ),
            ),
            Text('${_radiusKm.toStringAsFixed(1)} km',
                style: const TextStyle(fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

class _SelectedPostPanel extends StatelessWidget {
  final ListingModel post;
  final double? distanceMeters;
  final VoidCallback onDirections;
  final VoidCallback onClose;

  const _SelectedPostPanel({
    required this.post,
    required this.distanceMeters,
    required this.onDirections,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final distanceText = distanceMeters == null
        ? 'Chưa có vị trí hiện tại'
        : distanceMeters! >= 1000
        ? '${(distanceMeters! / 1000).toStringAsFixed(1)} km'
        : '${distanceMeters!.round()} m';

    return Container(
      constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.48),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 12),
                child: IconButton(
                  icon: const CircleAvatar(
                      backgroundColor: Colors.black54,
                      child: Icon(Icons.close, color: Colors.white, size: 20)),
                  onPressed: onClose,
                ),
              ),
            ),
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.near_me_outlined,
                            size: 18, color: Colors.blue),
                        const SizedBox(width: 6),
                        Expanded(child: Text('Khoảng cách: $distanceText')),
                        TextButton.icon(
                          onPressed: onDirections,
                          icon: const Icon(Icons.directions_outlined),
                          label: const Text('Chỉ đường'),
                        ),
                      ],
                    ),
                    PostCard(post: post),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
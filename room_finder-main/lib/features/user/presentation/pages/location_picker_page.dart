import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:uuid/uuid.dart';

import '../../../../data/services/location_service.dart';
import '../../../../core/config/google_maps_config.dart';

class PickedLocation {
  final GeoPoint point;
  final String address;
  final Map<String, String> addressComponents;

  const PickedLocation({
    required this.point,
    required this.address,
    this.addressComponents = const {},
  });
}

class LocationPickerPage extends StatefulWidget {
  final GeoPoint? initialLocation;
  final String? initialAddress;

  const LocationPickerPage({
    super.key,
    this.initialLocation,
    this.initialAddress,
  });

  @override
  State<LocationPickerPage> createState() => _LocationPickerPageState();
}

class _LocationPickerPageState extends State<LocationPickerPage> {
  final _mapController = MapController();
  final _uuid = const Uuid();
  final _locationService = LocationService();
  final _searchController = TextEditingController();
  Timer? _autocompleteDebounce;
  LatLng _selectedLatLng = const LatLng(10.762622, 106.660172);
  String _selectedAddress = '';
  Map<String, String> _selectedAddressComponents = {};
  List<PlacePrediction> _predictions = [];
  String? _autocompleteSessionToken;
  String? _predictionError;
  bool _isLoadingAddress = false;
  bool _isLoadingPredictions = false;

  @override
  void initState() {
    super.initState();
    final initialLocation = widget.initialLocation;
    if (initialLocation != null &&
        (initialLocation.latitude != 0 || initialLocation.longitude != 0)) {
      _selectedLatLng = LatLng(
        initialLocation.latitude,
        initialLocation.longitude,
      );
      _selectedAddress = widget.initialAddress ?? '';
      _searchController.text = _selectedAddress;

      if (_selectedAddress.trim().isEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _updateAddress(_selectedLatLng, fallback: widget.initialAddress);
        });
      }
    } else if (widget.initialAddress != null &&
        widget.initialAddress!.trim().isNotEmpty) {
      _selectedAddress = widget.initialAddress!;
      _searchController.text = _selectedAddress;
    } else {
      _loadCurrentLocation();
    }
  }

  @override
  void dispose() {
    _autocompleteDebounce?.cancel();
    _mapController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  String get _currentQuery => _searchController.text.trim();

  bool get _hasUncommittedQuery {
    final query = _currentQuery;
    return query.isNotEmpty && query != _selectedAddress;
  }

  String _newSessionToken() {
    return _autocompleteSessionToken ??= _uuid.v4();
  }

  void _resetSession() {
    _autocompleteSessionToken = null;
  }

  void _animateTo(LatLng target, {double zoom = 16}) {
    _mapController.move(target, zoom);
  }

  Future<void> _loadCurrentLocation() async {
    setState(() => _isLoadingAddress = true);
    final position = await _locationService.getCurrentPosition();
    if (position == null) {
      if (!mounted) return;
      setState(() => _isLoadingAddress = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không lấy được vị trí hiện tại')),
      );
      return;
    }
    if (!mounted) return;
    final latLng = LatLng(position.latitude, position.longitude);
    setState(() => _selectedLatLng = latLng);
    _animateTo(latLng);
    await _updateAddress(latLng);
  }

  Future<bool> _searchAddress() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return false;

    setState(() => _isLoadingAddress = true);
    try {
      final resolved = await _locationService.searchAddress(
        query,
        locationBias: GeoPoint(_selectedLatLng.latitude, _selectedLatLng.longitude),
      );
      if (resolved == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Không tìm thấy địa chỉ này')),
          );
        }
        return false;
      }
      _setResolvedLocation(resolved);
      _resetSession();
      return true;
    } catch (e) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không tìm thấy vị trí: $e')),
      );
      return false;
    } finally {
      if (mounted) setState(() => _isLoadingAddress = false);
    }
  }

  void _setResolvedLocation(ResolvedAddress resolved) {
    final latLng = LatLng(resolved.point.latitude, resolved.point.longitude);
    setState(() {
      _selectedLatLng = latLng;
      _selectedAddress = resolved.address;
      _selectedAddressComponents = resolved.components;
      _searchController.text = resolved.address;
      _predictions = [];
      _predictionError = null;
    });
    _animateTo(latLng);
  }

  void _onSearchChanged(String value) {
    _autocompleteDebounce?.cancel();
    final query = value.trim();
    if (query == _selectedAddress) {
      setState(() { _predictions = []; _predictionError = null; });
      return;
    }
    if (query.length < 2) {
      _resetSession();
      setState(() { _predictions = []; _predictionError = null; });
      return;
    }

    final token = _newSessionToken();
    _autocompleteDebounce = Timer(const Duration(milliseconds: 350), () async {
      if (!mounted) return;
      setState(() => _isLoadingPredictions = true);
      try {
        final predictions = await _locationService.autocompletePlaces(
          query,
          sessionToken: token,
          locationBias: GeoPoint(_selectedLatLng.latitude, _selectedLatLng.longitude),
        );
        if (!mounted || _searchController.text.trim() != query) return;
        setState(() { _predictions = predictions; _predictionError = null; });
      } catch (e) {
        if (!mounted) return;
        setState(() { _predictions = []; _predictionError = e.toString(); });
      } finally {
        if (mounted) setState(() => _isLoadingPredictions = false);
      }
    });
  }

  Future<bool> _selectPrediction(PlacePrediction prediction) async {
    setState(() {
      _isLoadingAddress = true;
      _predictions = [];
      _predictionError = null;
    });
    try {
      final resolved = await _locationService.getPlaceDetails(
        prediction.placeId,
        sessionToken: _autocompleteSessionToken,
      );
      if (resolved == null) return false;
      _setResolvedLocation(resolved);
      _resetSession();
      return true;
    } catch (e) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không lấy được chi tiết vị trí: $e')),
      );
      return false;
    } finally {
      if (mounted) setState(() => _isLoadingAddress = false);
    }
  }

  Future<void> _updateAddress(LatLng latLng, {String? fallback}) async {
    _resetSession();
    setState(() {
      _isLoadingAddress = true;
      _predictions = [];
      _predictionError = null;
    });
    try {
      final resolved = await _locationService.reverseGeocode(
        GeoPoint(latLng.latitude, latLng.longitude),
        fallback: fallback,
      );
      if (!mounted) return;
      setState(() {
        _selectedAddress = resolved.address;
        _selectedAddressComponents = resolved.components;
        _searchController.text = _selectedAddress;
        _predictions = [];
        _predictionError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _selectedAddress = fallback ?? '${latLng.latitude}, ${latLng.longitude}';
        _selectedAddressComponents = {'formattedAddress': _selectedAddress};
        _searchController.text = _selectedAddress;
        _predictions = [];
        _predictionError = null;
      });
    } finally {
      if (mounted) setState(() => _isLoadingAddress = false);
    }
  }

  Future<void> _confirm() async {
    if (_isLoadingAddress) return;
    if (_hasUncommittedQuery) {
      final resolved = _predictions.isNotEmpty
          ? await _selectPrediction(_predictions.first)
          : await _searchAddress();
      if (!resolved || !mounted) return;
    }
    Navigator.pop(
      context,
      PickedLocation(
        point: GeoPoint(_selectedLatLng.latitude, _selectedLatLng.longitude),
        address: _selectedAddress.isNotEmpty
            ? _selectedAddress
            : '${_selectedLatLng.latitude}, ${_selectedLatLng.longitude}',
        addressComponents: _selectedAddressComponents,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chọn vị trí',
            style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          TextButton(
            onPressed: _isLoadingAddress ? null : _confirm,
            child: const Text('Xong',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Bản đồ flutter_map + Mapbox
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _selectedLatLng,
              initialZoom: 15,
              onTap: (tapPosition, latLng) {
                setState(() => _selectedLatLng = latLng);
                _updateAddress(latLng);
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
                markers: [
                  Marker(
                    point: _selectedLatLng,
                    width: 48,
                    height: 48,
                    child: GestureDetector(
                      onPanUpdate: (details) {
                        // Drag marker bằng cách tap vị trí mới trên bản đồ
                      },
                      child: const Icon(
                        Icons.location_pin,
                        color: Colors.red,
                        size: 48,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Loading bar
          if (_isLoadingAddress)
            const Positioned(
              top: 0, left: 0, right: 0,
              child: LinearProgressIndicator(),
            ),

          // Search box
          Positioned(
            top: 12, left: 12, right: 12,
            child: Material(
              elevation: 4,
              borderRadius: BorderRadius.circular(12),
              child: TextField(
                controller: _searchController,
                textInputAction: TextInputAction.search,
                onChanged: _onSearchChanged,
                onSubmitted: (_) => _searchAddress(),
                decoration: InputDecoration(
                  hintText: 'Tìm địa chỉ hoặc địa danh',
                  prefixIcon: const Icon(Icons.search, color: Colors.blue),
                  suffixIcon: _isLoadingAddress
                      ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                      : IconButton(
                    icon: const Icon(Icons.my_location, color: Colors.blue),
                    onPressed: _loadCurrentLocation,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
            ),
          ),

          // Danh sách gợi ý
          if (_predictions.isNotEmpty)
            Positioned(
              top: 70, left: 12, right: 12,
              child: Material(
                elevation: 6,
                borderRadius: BorderRadius.circular(12),
                color: Colors.white,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.34,
                  ),
                  child: ListView.separated(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    itemCount: _predictions.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final prediction = _predictions[index];
                      return ListTile(
                        leading: const Icon(Icons.location_on_outlined,
                            color: Colors.blue),
                        title: Text(prediction.primaryText,
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: prediction.secondaryText.isEmpty
                            ? null
                            : Text(prediction.secondaryText,
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        onTap: () => _selectPrediction(prediction),
                      );
                    },
                  ),
                ),
              ),
            )
          else if (_predictionError != null && _currentQuery.length >= 2)
            Positioned(
              top: 70, left: 12, right: 12,
              child: Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(12),
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline, color: Colors.orange),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Không tải được gợi ý. Nhấn tìm kiếm để thử trực tiếp.',
                          style: TextStyle(color: Colors.grey.shade700),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else if (_isLoadingPredictions)
              Positioned(
                top: 70, left: 24, right: 24,
                child: Material(
                  elevation: 3,
                  borderRadius: BorderRadius.circular(999),
                  color: Colors.white,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 16, height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 12),
                        Text('Đang tìm địa điểm...'),
                      ],
                    ),
                  ),
                ),
              ),

          // Bottom: địa chỉ + nút xác nhận
          Positioned(
            left: 16, right: 16, bottom: 24,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_selectedAddress.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: const [
                        BoxShadow(color: Colors.black12, blurRadius: 8)
                      ],
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.location_on, color: Colors.red),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _selectedAddress,
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w500),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isLoadingAddress ? null : _loadCurrentLocation,
                        icon: const Icon(Icons.my_location),
                        label: const Text('Vị trí hiện tại'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 54),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isLoadingAddress ? null : _confirm,
                        icon: const Icon(Icons.check_circle),
                        label: const Text('XÁC NHẬN',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[800],
                          foregroundColor: Colors.white,
                          minimumSize: const Size(0, 54),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
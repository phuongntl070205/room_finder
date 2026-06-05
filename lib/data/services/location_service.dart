import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geocoding/geocoding.dart' as geocoding;
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

class ResolvedAddress {
  final GeoPoint point;
  final String address;
  final Map<String, String> components;
  final String? placeId;
  final String? name;

  const ResolvedAddress({
    required this.point,
    required this.address,
    required this.components,
    this.placeId,
    this.name,
  });
}

class PlacePrediction {
  final String placeId;
  final String description;
  final String primaryText;
  final String secondaryText;

  const PlacePrediction({
    required this.placeId,
    required this.description,
    required this.primaryText,
    required this.secondaryText,
  });
}

class LocationService {
  static const _userAgent = 'RoomFinderApp/1.0';
  final http.Client _client;

  LocationService({http.Client? client}) : _client = client ?? http.Client();

  // ─── Vị trí hiện tại ──────────────────────────────────────────────────────

  Future<Position?> getCurrentPosition() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return null;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return null;
    }

    return Geolocator.getCurrentPosition();
  }

  double distanceInMeters(
      double startLatitude,
      double startLongitude,
      double endLatitude,
      double endLongitude,
      ) {
    return Geolocator.distanceBetween(
      startLatitude,
      startLongitude,
      endLatitude,
      endLongitude,
    );
  }

  // ─── API công khai ─────────────────────────────────────────────────────────

  Future<ResolvedAddress?> resolve({
    GeoPoint? point,
    String? address,
  }) async {
    final query = address?.trim();
    if (query != null && query.isNotEmpty) {
      final resolved = await searchAddress(query, locationBias: point);
      if (resolved != null) return resolved;
    }
    if (point != null && (point.latitude != 0 || point.longitude != 0)) {
      return reverseGeocode(point, fallback: address);
    }
    return null;
  }

  Future<ResolvedAddress?> searchAddress(
      String query, {
        GeoPoint? locationBias,
      }) async {
    try {
      return await _geocodeAddress(query, locationBias: locationBias);
    } catch (_) {
      return _nativeGeocodeAddress(query);
    }
  }

  /// Gợi ý địa chỉ dùng Nominatim (không cần key)
  Future<List<PlacePrediction>> autocompletePlaces(
      String query, {
        String? sessionToken,
        GeoPoint? locationBias,
      }) async {
    final input = query.trim();
    if (input.isEmpty) return [];

    try {
      final uri = Uri.https(
        'nominatim.openstreetmap.org',
        '/search',
        {
          'q': '$input, Việt Nam',
          'format': 'json',
          'limit': '5',
          'accept-language': 'vi',
          'countrycodes': 'vn',
          'addressdetails': '1',
        },
      );

      final response = await _client.get(uri, headers: {'User-Agent': _userAgent});
      final results = jsonDecode(response.body) as List<dynamic>;

      return results.map((item) {
        final place = item as Map<String, dynamic>;
        final displayName = place['display_name'] as String? ?? '';
        final parts = displayName.split(',');
        final primary = parts.isNotEmpty ? parts.first.trim() : displayName;
        final secondary = parts.length > 1
            ? parts.sublist(1).join(',').trim()
            : '';
        return PlacePrediction(
          placeId: place['place_id']?.toString() ?? '',
          description: displayName,
          primaryText: primary,
          secondaryText: secondary,
        );
      }).where((p) => p.placeId.isNotEmpty).toList();
    } catch (_) {
      return [];
    }
  }

  /// Lấy chi tiết địa điểm từ place_id của Nominatim
  Future<ResolvedAddress?> getPlaceDetails(
      String placeId, {
        String? sessionToken,
      }) async {
    try {
      final uri = Uri.https(
        'nominatim.openstreetmap.org',
        '/details',
        {
          'place_id': placeId,
          'format': 'json',
          'accept-language': 'vi',
          'addressdetails': '1',
        },
      );

      final response = await _client.get(uri, headers: {'User-Agent': _userAgent});
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final centroid = data['centroid'] as Map<String, dynamic>?;
      final coords = centroid?['coordinates'] as List<dynamic>?;
      if (coords == null || coords.length < 2) return null;

      final lon = (coords[0] as num).toDouble();
      final lat = (coords[1] as num).toDouble();
      final point = GeoPoint(lat, lon);

      return reverseGeocode(point);
    } catch (_) {
      return null;
    }
  }

  // ─── Reverse geocode dùng Nominatim ───────────────────────────────────────

  Future<ResolvedAddress> reverseGeocode(
      GeoPoint point, {
        String? fallback,
      }) async {
    try {
      final uri = Uri.https(
        'nominatim.openstreetmap.org',
        '/reverse',
        {
          'lat': '${point.latitude}',
          'lon': '${point.longitude}',
          'format': 'json',
          'accept-language': 'vi',
          'addressdetails': '1',
        },
      );

      final response = await _client.get(uri, headers: {'User-Agent': _userAgent});

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('Nominatim HTTP ${response.statusCode}');
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final addr = data['address'] as Map<String, dynamic>? ?? {};
      print('=== Nominatim address fields: ${data['address']}');

      final houseNumber = addr['house_number'] as String? ?? '';
      final road = addr['road'] as String? ?? '';
      final street = [houseNumber, road]
          .where((s) => s.isNotEmpty)
          .join(' ');

      final ward = addr['suburb'] as String?
          ?? addr['quarter'] as String?
          ?? addr['neighbourhood'] as String?
          ?? addr['village'] as String?
          ?? '';

      final iso = addr['ISO3166-2-lvl4'] as String? ?? '';
      final province = () {
        // Map ISO code sang tên tỉnh/thành đúng
        const isoMap = {
          'VN-SG': 'Thành phố Hồ Chí Minh',
          'VN-HN': 'Thành phố Hà Nội',
          'VN-DN': 'Thành phố Đà Nẵng',
          'VN-CT': 'Thành phố Cần Thơ',
          'VN-HP': 'Thành phố Hải Phòng',
        };
        if (isoMap.containsKey(iso)) return isoMap[iso]!;

        // Các tỉnh khác dùng state hoặc city
        return addr['state'] as String?
            ?? addr['city'] as String?
            ?? addr['town'] as String?
            ?? '';
      }();

      final country = addr['country'] as String? ?? '';

      final parts = [street, ward, province]
          .where((s) => s.isNotEmpty)
          .toList();

      final uniqueParts = <String>[];
      for (final part in parts) {
        if (!uniqueParts.any((e) => _isDuplicate(e, part))) {
          uniqueParts.add(part);
        }
      }

      final formattedAddress = uniqueParts.isNotEmpty
          ? uniqueParts.join(', ')
          : (fallback ?? '${point.latitude}, ${point.longitude}');

      return ResolvedAddress(
        point: point,
        address: formattedAddress,
        components: {
          if (street.isNotEmpty) 'street': street,
          if (ward.isNotEmpty) 'ward': ward,
          if (province.isNotEmpty) 'province': province,
          if (country.isNotEmpty) 'country': country,
          'formattedAddress': formattedAddress,
        },
      );
    } catch (e) {
      // Fallback sang geocoding package
      return await _nativeReverseGeocode(point, fallback: fallback)
          ?? _fallback(point, fallback);
    }
  }

  // ─── Geocode địa chỉ dùng Nominatim ───────────────────────────────────────

  Future<ResolvedAddress?> _geocodeAddress(
      String query, {
        GeoPoint? locationBias,
      }) async {
    final uri = Uri.https(
      'nominatim.openstreetmap.org',
      '/search',
      {
        'q': _withVietnamSuffix(query),
        'format': 'json',
        'limit': '1',
        'accept-language': 'vi',
        'countrycodes': 'vn',
        'addressdetails': '1',
      },
    );

    final response = await _client.get(uri, headers: {'User-Agent': _userAgent});
    final results = jsonDecode(response.body) as List<dynamic>;
    if (results.isEmpty) return null;

    final first = results.first as Map<String, dynamic>;
    final lat = double.tryParse(first['lat'] as String? ?? '') ?? 0;
    final lon = double.tryParse(first['lon'] as String? ?? '') ?? 0;
    final point = GeoPoint(lat, lon);

    return reverseGeocode(point, fallback: query);
  }

  // ─── Fallback dùng geocoding package ──────────────────────────────────────

  Future<ResolvedAddress?> _nativeGeocodeAddress(String query) async {
    final input = _withVietnamSuffix(query.trim());
    if (input.isEmpty) return null;

    try {
      final locations = await geocoding.locationFromAddress(input);
      if (locations.isEmpty) return null;

      final first = locations.first;
      final point = GeoPoint(first.latitude, first.longitude);
      return await _nativeReverseGeocode(point, fallback: input) ??
          ResolvedAddress(
            point: point,
            address: input,
            components: {'formattedAddress': input},
          );
    } catch (_) {
      return null;
    }
  }

  Future<ResolvedAddress?> _nativeReverseGeocode(
      GeoPoint point, {
        String? fallback,
      }) async {
    try {
      final placemarks = await geocoding.placemarkFromCoordinates(
        point.latitude,
        point.longitude,
      );
      if (placemarks.isEmpty) return null;

      final placemark = placemarks.first;
      final components = _componentsFromPlacemark(placemark);
      final address = components['formattedAddress']?.trim();

      return ResolvedAddress(
        point: point,
        address: address?.isNotEmpty == true
            ? address!
            : (fallback?.trim().isNotEmpty == true
            ? fallback!.trim()
            : '${point.latitude}, ${point.longitude}'),
        components: components,
      );
    } catch (_) {
      return null;
    }
  }

  // ─── Helper ───────────────────────────────────────────────────────────────

  Map<String, String> _componentsFromPlacemark(geocoding.Placemark placemark) {
    String clean(String? value) => value?.trim() ?? '';

    final name = clean(placemark.name);
    final streetRaw = clean(placemark.street);
    final street = (streetRaw.contains(name) || name.isEmpty)
        ? streetRaw
        : (name.contains(streetRaw) ? name : '$name $streetRaw');

    final ward = [
      clean(placemark.subLocality),
      clean(placemark.locality),
    ].firstWhere((s) => s.isNotEmpty, orElse: () => '');

    final province = clean(placemark.administrativeArea);
    final country = clean(placemark.country);

    final parts = [street, ward, province]
        .where((part) => part.trim().isNotEmpty)
        .toList();

    final uniqueParts = <String>[];
    for (final part in parts) {
      if (!uniqueParts.any((existing) => _isDuplicate(existing, part))) {
        uniqueParts.add(part);
      }
    }

    return {
      if (street.trim().isNotEmpty) 'street': street.trim(),
      if (ward.isNotEmpty) 'ward': ward,
      if (province.isNotEmpty) 'province': province,
      if (country.isNotEmpty) 'country': country,
      'formattedAddress': uniqueParts.join(', '),
    };
  }

  ResolvedAddress _fallback(GeoPoint point, String? fallback) {
    final address = fallback?.trim();
    return ResolvedAddress(
      point: point,
      address: address?.isNotEmpty == true
          ? address!
          : '${point.latitude}, ${point.longitude}',
      components: {
        if (address?.isNotEmpty == true) 'formattedAddress': address!,
      },
    );
  }

  String _withVietnamSuffix(String query) {
    final lower = query.toLowerCase();
    if (lower.contains('việt nam') || lower.contains('viet nam')) return query;
    return '$query, Việt Nam';
  }

  bool _isDuplicate(String full, String part) {
    if (full.isEmpty || part.isEmpty) return false;
    final a = full.toLowerCase();
    final b = part.toLowerCase();
    return a.contains(b) || b.contains(a);
  }
}
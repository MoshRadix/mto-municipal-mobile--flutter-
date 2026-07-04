import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter/foundation.dart';

class LocationService {
  // Check permission and fetch coordinates + address
  Future<Map<String, String>> getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Check if location services are enabled.
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permissions are denied.');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception(
        'Location permissions are permanently denied, we cannot request permissions.',
      );
    }

    // Get current position
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 8),
      ),
    );

    final String coordinates =
        '${position.latitude.toStringAsFixed(6)},${position.longitude.toStringAsFixed(6)}';
    String readableAddress = 'Unknown Address';
    String nearestPlace = '';

    // Reverse geocode
    try {
      final List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        final placemark = placemarks.first;
        final parts = <String>[];

        nearestPlace =
            [
                  placemark.street,
                  placemark.name,
                  placemark.subLocality,
                  placemark.locality,
                ]
                .whereType<String>()
                .map((part) => part.trim())
                .firstWhere((part) => part.isNotEmpty, orElse: () => '');

        if (placemark.street != null && placemark.street!.isNotEmpty) {
          parts.add(placemark.street!);
        }
        if (placemark.subLocality != null &&
            placemark.subLocality!.isNotEmpty) {
          parts.add(placemark.subLocality!);
        }
        if (placemark.locality != null && placemark.locality!.isNotEmpty) {
          parts.add(placemark.locality!);
        }
        if (placemark.country != null && placemark.country!.isNotEmpty) {
          parts.add(placemark.country!);
        }

        if (parts.isNotEmpty) {
          readableAddress = parts.join(', ');
        }
      }
    } catch (e) {
      debugPrint('Reverse geocoding error: $e');
      readableAddress = 'Addu City, Maldives'; // Generic fallback
    }

    return {
      'coordinates': coordinates,
      'address': readableAddress,
      'place': nearestPlace,
    };
  }
}

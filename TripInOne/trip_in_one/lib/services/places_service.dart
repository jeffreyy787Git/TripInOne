import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class PlacesService {
  final Dio _dio = Dio();
  final String _baseUrl = 'https://maps.googleapis.com/maps/api/place/nearbysearch/json?';

  Future<List<Map<String, dynamic>>> getNearbyPlaces(
    LatLng location, {
    String type = 'tourist_attraction',
  }) async {
    try {
      final response = await _dio.get(
        _baseUrl,
        queryParameters: {
          'location': '${location.latitude},${location.longitude}',
          'radius': '5000',
          'type': type,
          'key': dotenv.env['GOOGLE_MAPS_API_KEY'],
        },
      );

      if (response.data['results'] != null) {
        return List<Map<String, dynamic>>.from(response.data['results']);
      }
      return [];
    } catch (e) {
      print('Error fetching places: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> getPlaceDetails(String placeId) async {
    try {
      final response = await _dio.get(
        'https://maps.googleapis.com/maps/api/place/details/json',
        queryParameters: {
          'place_id': placeId,
          'fields': 'name,rating,formatted_phone_number,formatted_address,opening_hours,photos,reviews,website',
          'key': dotenv.env['GOOGLE_MAPS_API_KEY'],
        },
      );

      if (response.data['result'] != null) {
        return Map<String, dynamic>.from(response.data['result']);
      }
      return {};
    } catch (e) {
      print('Error fetching place details: $e');
      return {};
    }
  }
} 
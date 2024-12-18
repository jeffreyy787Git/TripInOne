import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';

class DirectionsService {
  final Dio _dio = Dio();
  final String _baseUrl = 'https://maps.googleapis.com/maps/api/directions/json?';
  
  Future<Map<String, dynamic>> getDirections({
    required LatLng origin,
    required LatLng destination,
  }) async {
    final response = await _dio.get(
      _baseUrl,
      queryParameters: {
        'origin': '${origin.latitude},${origin.longitude}',
        'destination': '${destination.latitude},${destination.longitude}',
        'key': dotenv.env['GOOGLE_MAPS_API_KEY'],
      },
    );

    // 解碼聚合線點
    List<LatLng> polylinePoints = [];
    if (response.data['routes'].isNotEmpty) {
      String points = response.data['routes'][0]['overview_polyline']['points'];
      PolylinePoints polylineDecoder = PolylinePoints();
      List<PointLatLng> decodedPoints = 
          polylineDecoder.decodePolyline(points);

      polylinePoints = decodedPoints
          .map((point) => LatLng(point.latitude, point.longitude))
          .toList();
    }

    return {
      'polylinePoints': polylinePoints,
      'duration': response.data['routes'][0]['legs'][0]['duration']['text'],
      'distance': response.data['routes'][0]['legs'][0]['distance']['text'],
    };
  }
} 
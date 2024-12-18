import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../services/places_service.dart';

class PlaceDetailsScreen extends StatefulWidget {
  final String placeId;
  final String placeName;
  final String placeType;

  const PlaceDetailsScreen({
    Key? key,
    required this.placeId,
    required this.placeName,
    required this.placeType,
  }) : super(key: key);

  @override
  State<PlaceDetailsScreen> createState() => _PlaceDetailsScreenState();
}

class _PlaceDetailsScreenState extends State<PlaceDetailsScreen> {
  final PlacesService _placesService = PlacesService();
  Map<String, dynamic>? _placeDetails;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPlaceDetails();
  }

  Future<void> _loadPlaceDetails() async {
    final details = await _placesService.getPlaceDetails(widget.placeId);
    setState(() {
      _placeDetails = details;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.placeName),
        backgroundColor: widget.placeType == 'attraction' 
            ? Colors.purple 
            : Colors.orange,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_placeDetails?['photos'] != null)
                    Container(
                      height: 200,
                      width: double.infinity,
                      child: Image.network(
                        'https://maps.googleapis.com/maps/api/place/photo'
                        '?maxwidth=400'
                        '&photo_reference=${_placeDetails!['photos'][0]['photo_reference']}'
                        '&key=${dotenv.env['GOOGLE_MAPS_API_KEY']}',
                        fit: BoxFit.cover,
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_placeDetails?['rating'] != null)
                          Row(
                            children: [
                              Text(
                                'Rating: ${_placeDetails!['rating']}',
                                style: const TextStyle(fontSize: 16),
                              ),
                              const SizedBox(width: 8),
                              Icon(Icons.star, color: Colors.amber),
                            ],
                          ),
                        const SizedBox(height: 8),
                        if (_placeDetails?['formatted_address'] != null)
                          Text(
                            'Address: ${_placeDetails!['formatted_address']}',
                            style: const TextStyle(fontSize: 16),
                          ),
                        const SizedBox(height: 8),
                        if (_placeDetails?['formatted_phone_number'] != null)
                          Text(
                            'Phone: ${_placeDetails!['formatted_phone_number']}',
                            style: const TextStyle(fontSize: 16),
                          ),
                        const SizedBox(height: 16),
                        if (_placeDetails?['opening_hours'] != null) ...[
                          const Text(
                            'Opening Hours:',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ...(_placeDetails!['opening_hours']['weekday_text']
                              as List)
                              .map((text) => Padding(
                                    padding: const EdgeInsets.only(bottom: 4),
                                    child: Text(text),
                                  )),
                        ],
                        const SizedBox(height: 16),
                        if (_placeDetails?['reviews'] != null) ...[
                          const Text(
                            'Reviews:',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ..._placeDetails!['reviews'].take(3).map((review) =>
                              Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            review['author_name'],
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text('${review['rating']}★'),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(review['text']),
                                    ],
                                  ),
                                ),
                              )),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
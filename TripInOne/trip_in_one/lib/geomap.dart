import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'services/directions_service.dart';
import 'services/places_service.dart';
import 'screens/place_details_screen.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'dart:async';
import 'package:flutter/services.dart';

class GeoMapPage extends StatefulWidget {
  final LatLng? initialLocation;
  
  const GeoMapPage({
    super.key,
    this.initialLocation,
  });

  @override
  State<GeoMapPage> createState() => _GeoMapPageState();
}

class _GeoMapPageState extends State<GeoMapPage> with WidgetsBindingObserver {
  GoogleMapController? _mapController;
  Position? _currentPosition;
  LatLng? _currentDestination;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  final DirectionsService _directionsService = DirectionsService();
  String? _duration;
  String? _distance;
  final PlacesService _placesService = PlacesService();
  bool _showAttractions = true;
  bool _showRestaurants = false;
  bool _showHotels = false;
  Map<String, Set<Marker>> _filteredMarkers = {
    'attractions': {},
    'restaurants': {},
    'hotels': {},
  };
  StreamSubscription? _accelerometerSubscription;
  DateTime? _lastShakeTime;
  static const double _shakeThreshold = 200.0;
  static const Duration _cooldownDuration = Duration(seconds: 2);
  List<double> _lastAccelerations = [];
  static const int _accelerationBufferSize = 5;
  bool _isPageActive = true;

  Future<void> _getCurrentLocation() async {
    final permission = await Permission.location.request();
    if (permission.isDenied) {
      return;
    }

    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _currentPosition = position;
      });

      _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(position.latitude, position.longitude),
            zoom: 15,
          ),
        ),
      );
    } catch (e) {
      debugPrint('Error getting location: $e');
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    if (_currentPosition != null) {
      controller.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
            zoom: 15,
          ),
        ),
      );
    }
  }

  void _addDestinationMarker(LatLng position) async {
    _currentDestination = position;
    setState(() {
      _markers.removeWhere((marker) => 
        marker.markerId == const MarkerId('destination'));
      
      _markers.add(
        Marker(
          markerId: const MarkerId('destination'),
          position: position,
          infoWindow: const InfoWindow(title: 'Destination'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        ),
      );
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Tap the check icon to confirm location'),
        duration: Duration(seconds: 2),
      ),
    );
    
    if (_currentPosition != null) {
      await _getDirections(
        LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
        position,
      );
    }
  }

  Future<void> _getDirections(LatLng origin, LatLng destination) async {
    try {
      final directions = await _directionsService.getDirections(
        origin: origin,
        destination: destination,
      );

      setState(() {
        _polylines.clear();
        _polylines.add(
          Polyline(
            polylineId: const PolylineId('route'),
            points: directions['polylinePoints'],
            color: Colors.blue,
            width: 5,
          ),
        );
        _duration = directions['duration'];
        _distance = directions['distance'];
      });
    } catch (e) {
      debugPrint('Error getting directions: $e');
    }
  }

  Future<void> _loadNearbyPlaces() async {
    if (_currentPosition == null) return;
    
    _filteredMarkers['attractions']?.clear();
    _filteredMarkers['restaurants']?.clear();
    _filteredMarkers['hotels']?.clear();

    if (_showAttractions) {
      final attractions = await _placesService.getNearbyPlaces(
        LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
        type: 'tourist_attraction',
      );

      for (var place in attractions) {
        final location = place['geometry']['location'];
        _filteredMarkers['attractions']?.add(
          Marker(
            markerId: MarkerId('attraction_${place['place_id']}'),
            position: LatLng(location['lat'], location['lng']),
            infoWindow: InfoWindow(
              title: place['name'],
              snippet: place['vicinity'],
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PlaceDetailsScreen(
                      placeId: place['place_id'],
                      placeName: place['name'],
                      placeType: 'attraction',
                    ),
                  ),
                );
              },
            ),
            icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueViolet,
            ),
          ),
        );
      }
    }

    if (_showRestaurants) {
      final restaurants = await _placesService.getNearbyPlaces(
        LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
        type: 'restaurant',
      );

      for (var place in restaurants) {
        final location = place['geometry']['location'];
        _filteredMarkers['restaurants']?.add(
          Marker(
            markerId: MarkerId('restaurant_${place['place_id']}'),
            position: LatLng(location['lat'], location['lng']),
            infoWindow: InfoWindow(
              title: place['name'],
              snippet: place['vicinity'],
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PlaceDetailsScreen(
                      placeId: place['place_id'],
                      placeName: place['name'],
                      placeType: 'restaurant',
                    ),
                  ),
                );
              },
            ),
            icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueOrange,
            ),
          ),
        );
      }
    }

    if (_showHotels) {
      final hotels = await _placesService.getNearbyPlaces(
        LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
        type: 'lodging',
      );

      for (var place in hotels) {
        final location = place['geometry']['location'];
        _filteredMarkers['hotels']?.add(
          Marker(
            markerId: MarkerId('hotel_${place['place_id']}'),
            position: LatLng(location['lat'], location['lng']),
            infoWindow: InfoWindow(
              title: place['name'],
              snippet: place['vicinity'],
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PlaceDetailsScreen(
                      placeId: place['place_id'],
                      placeName: place['name'],
                      placeType: 'hotel',
                    ),
                  ),
                );
              },
            ),
            icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueGreen,
            ),
          ),
        );
      }
    }

    setState(() {
      _markers = {
        if (_currentDestination != null)
          Marker(
            markerId: const MarkerId('destination'),
            position: _currentDestination!,
            infoWindow: const InfoWindow(title: 'Destination'),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          ),
        ..._filteredMarkers['attractions'] ?? {},
        ..._filteredMarkers['restaurants'] ?? {},
        ..._filteredMarkers['hotels'] ?? {},
      };
    });
  }

  Future<void> _selectRandomPlace() async {
    if (!mounted || !_isPageActive || _currentPosition == null) return;

    try {
      String type;
      if (_showAttractions) {
        type = 'tourist_attraction';
      } else if (_showRestaurants) {
        type = 'restaurant';
      } else if (_showHotels) {
        type = 'lodging';
      } else {
        type = 'tourist_attraction';
      }

      final randomPlace = await _placesService.getRandomPlace(
        LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
        type: type,
      );

      if (!mounted || !_isPageActive) return;

      if (randomPlace != null) {
        final location = randomPlace['geometry']['location'];
        final position = LatLng(location['lat'], location['lng']);
        
        if (!mounted || !_isPageActive) return;

        try {
          _mapController?.animateCamera(
            CameraUpdate.newLatLng(position),
          );

          _addDestinationMarker(position);
        } catch (e) {
          debugPrint('Map operation error: $e');
          return;
        }

        if (!mounted || !_isPageActive) return;
        
        try {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PlaceDetailsScreen(
                placeId: randomPlace['place_id'],
                placeName: randomPlace['name'],
                placeType: type == 'tourist_attraction' ? 'attraction' : 'restaurant',
              ),
            ),
          );
        } catch (e) {
          debugPrint('Navigation cancelled: $e');
        }
      } else {
        if (!mounted || !_isPageActive) return;
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No places found nearby. Try changing filters or location.'),
          ),
        );
      }
    } catch (e) {
      if (!mounted || !_isPageActive) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
        ),
      );
    }
  }

  void _initShakeDetection() {
    _accelerometerSubscription = accelerometerEventStream().listen(
      (AccelerometerEvent event) {
        if (!mounted || !_isPageActive) return;
        
        try {
          double acceleration = event.x * event.x + 
                              event.y * event.y + 
                              event.z * event.z;
          
          _lastAccelerations.add(acceleration);
          if (_lastAccelerations.length > _accelerationBufferSize) {
            _lastAccelerations.removeAt(0);
          }
          
          double averageAcceleration = _lastAccelerations.isEmpty 
              ? 0 
              : _lastAccelerations.reduce((a, b) => a + b) / _lastAccelerations.length;
                                      
          if (averageAcceleration > _shakeThreshold) {
            final now = DateTime.now();
            if (_lastShakeTime == null || 
                now.difference(_lastShakeTime!) > _cooldownDuration) {
              _lastShakeTime = now;
              
              if (!mounted || !_isPageActive) return;
              
              _selectRandomPlace();
              _lastAccelerations.clear();
              
              HapticFeedback.mediumImpact();
              
              if (!mounted || !_isPageActive) return;
              
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Searching for a random place...'),
                  duration: Duration(seconds: 1),
                ),
              );
            }
          }
        } catch (e) {
          debugPrint('Shake detection error: $e');
        }
      },
      onError: (error) {
        debugPrint('Accelerometer error: $error');
      },
      cancelOnError: false,
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _isPageActive = true;
    _initializeMap();
    _initShakeDetection();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    _isPageActive = state == AppLifecycleState.resumed;
  }

  Future<void> _initializeMap() async {
    if (!mounted) return;
    try {
      await _getCurrentLocation();
      if (mounted && _isPageActive) {
        await _loadNearbyPlaces();
        if (mounted && _isPageActive) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Shake to find a random place!'),
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted && _isPageActive) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Initializing map error: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _accelerometerSubscription?.cancel();
    _mapController?.dispose();
    _isPageActive = false;
    super.dispose();
  }

  Widget _buildFilterChips() {
    return Container(
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Wrap(
        spacing: 8.0,
        children: [
          FilterChip(
            label: const Text('Attraction'),
            selected: _showAttractions,
            onSelected: (bool selected) {
              setState(() {
                _showAttractions = selected;
                _loadNearbyPlaces();
              });
            },
            selectedColor: Colors.purple.withOpacity(0.3),
          ),
          FilterChip(
            label: const Text('Restaurant'),
            selected: _showRestaurants,
            onSelected: (bool selected) {
              setState(() {
                _showRestaurants = selected;
                _loadNearbyPlaces();
              });
            },
            selectedColor: Colors.orange.withOpacity(0.3),
          ),
          FilterChip(
            label: const Text('Hotel'),
            selected: _showHotels,
            onSelected: (bool selected) {
              setState(() {
                _showHotels = selected;
                _loadNearbyPlaces();
              });
            },
            selectedColor: Colors.green.withOpacity(0.3),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Map'),
        actions: [
          if (_currentDestination != null)
            IconButton(
              icon: const Icon(Icons.check),
              onPressed: () {
                Navigator.pop(context, _currentDestination);
              },
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadNearbyPlaces,
          ),
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: _getCurrentLocation,
          ),
        ],
      ),
      body: Stack(
        children: [
          if (_currentPosition == null)
            const Center(child: CircularProgressIndicator())
          else
            GoogleMap(
              onMapCreated: _onMapCreated,
              initialCameraPosition: CameraPosition(
                target: LatLng(
                  _currentPosition!.latitude,
                  _currentPosition!.longitude,
                ),
                zoom: 15,
              ),
              markers: _markers,
              polylines: _polylines,
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
              onTap: _addDestinationMarker,
            ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _buildFilterChips(),
          ),
          if (_duration != null && _distance != null)
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.directions_walk, color: Colors.blue),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'Distance',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                              Text(
                                _distance!,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Container(
                        height: 24,
                        width: 1,
                        color: Colors.grey.withOpacity(0.3),
                      ),
                      Row(
                        children: [
                          const Icon(Icons.access_time, color: Colors.blue),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'Duration',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                              Text(
                                _duration!,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}


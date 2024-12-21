import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../travel_planner.dart';

class TravelPlanService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Stream<Map<DateTime, List<PlanItem>>> getUserPlans() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return Stream.value({});

    return _firestore
        .collection('users')
        .doc(userId)
        .collection('plans')
        .snapshots()
        .map((snapshot) {
      Map<DateTime, List<PlanItem>> plans = {};
      
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final date = DateTime.parse(doc.id);
        final plansList = (data['plans'] as List<dynamic>).map((plan) {
          return PlanItem(
            id: plan['id'],
            time: plan['time'],
            title: plan['title'],
            description: plan['description'],
            location: plan['location'] != null
                ? LatLng(
                    plan['location']['latitude'],
                    plan['location']['longitude'],
                  )
                : null,
          );
        }).toList();
        
        plans[date] = plansList;
      }
      
      return plans;
    });
  }

  Future<void> saveDayPlans(DateTime date, List<PlanItem> plans) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    final dateStr = date.toIso8601String().split('T')[0];
    
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('plans')
        .doc(dateStr)
        .set({
          'plans': plans.map((plan) => {
            'id': plan.id,
            'time': plan.time,
            'title': plan.title,
            'description': plan.description,
            'location': plan.location != null
                ? {
                    'latitude': plan.location!.latitude,
                    'longitude': plan.location!.longitude,
                  }
                : null,
          }).toList(),
        });
  }

  Future<void> deleteDayPlans(DateTime date) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    final dateStr = date.toIso8601String().split('T')[0];
    
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('plans')
        .doc(dateStr)
        .delete();
  }
} 
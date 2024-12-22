import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'geomap.dart';
import '../services/travel_plan_service.dart';
import 'dart:async';

class TravelPlannerPage extends StatefulWidget {
  const TravelPlannerPage({super.key});

  @override
  State<TravelPlannerPage> createState() => _TravelPlannerPageState();
}

class _TravelPlannerPageState extends State<TravelPlannerPage> {
  DateTime _selectedDay = DateTime.now();
  DateTime _focusedDay = DateTime.now();
  bool _showCalendar = false;
  Map<DateTime, List<PlanItem>> _plans = {};
  final TravelPlanService _planService = TravelPlanService();
  StreamSubscription? _planSubscription;

  @override
  void initState() {
    super.initState();
    _loadPlans();
  }

  void _loadPlans() {
    _planSubscription = _planService.getUserPlans().listen((plans) {
      setState(() {
        _plans = plans;
      });
    });
  }

  @override
  void dispose() {
    _planSubscription?.cancel();
    super.dispose();
  }

  List<PlanItem> _getPlansForSelectedDay() {
    final normalizedSelectedDay = DateTime(
      _selectedDay.year,
      _selectedDay.month,
      _selectedDay.day,
    );
    
    return _plans.entries
        .where((entry) => entry.key.year == normalizedSelectedDay.year &&
                         entry.key.month == normalizedSelectedDay.month &&
                         entry.key.day == normalizedSelectedDay.day)
        .map((entry) => entry.value)
        .firstOrNull ?? [];
  }

  List<PlanItem> _sortPlansByTime(List<PlanItem> plans) {
    return List<PlanItem>.from(plans)..sort((a, b) {
      final aTimeParts = a.time.split(':');
      final bTimeParts = b.time.split(':');
      
      final aHour = int.parse(aTimeParts[0]);
      final bHour = int.parse(bTimeParts[0]);
      
      if (aHour != bHour) {
        return aHour.compareTo(bHour);
      }
      
      final aMinute = int.parse(aTimeParts[1]);
      final bMinute = int.parse(bTimeParts[1]);
      return aMinute.compareTo(bMinute);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: _buildPlanList(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddPlanDialog,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withOpacity(0.1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            DateFormat('yyyy/MM/dd').format(_selectedDay),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: () {
              setState(() {
                _showCalendar = !_showCalendar;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPlanList() {
    final plans = _getPlansForSelectedDay();
    
    return Column(
      children: [
        if (_showCalendar)
          TableCalendar(
            firstDay: DateTime.utc(2024, 1, 1),
            lastDay: DateTime.utc(2025, 12, 31),
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) {
              return isSameDay(_selectedDay, day);
            },
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
                _showCalendar = false;
              });
            },
          ),
        Expanded(
          child: plans.isEmpty
              ? const Center(
                  child: Text('No plans for this day'),
                )
              : ReorderableListView(
                  onReorder: (oldIndex, newIndex) {
                    setState(() {
                      if (newIndex > oldIndex) {
                        newIndex -= 1;
                      }
                      final item = plans.removeAt(oldIndex);
                      plans.insert(newIndex, item);
                      
                      final sortedPlans = _sortPlansByTime(plans);
                      _plans[_selectedDay] = sortedPlans;
                      _planService.saveDayPlans(_selectedDay, sortedPlans);
                    });
                  },
                  children: plans.map((plan) {
                    return Card(
                      key: ValueKey(plan.id),
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 8.0,
                      ),
                      child: ListTile(
                        leading: Text(plan.time),
                        title: Text(plan.title),
                        subtitle: Text(plan.description),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (plan.location != null)
                              IconButton(
                                icon: const Icon(Icons.map),
                                onPressed: () async {
                                  final newLocation = await Navigator.push<LatLng>(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => GeoMapPage(
                                        initialLocation: plan.location,
                                        isSelectingLocation: true,
                                      ),
                                    ),
                                  );
                                  
                                  if (newLocation != null) {
                                    setState(() {
                                      final plans = _getPlansForSelectedDay();
                                      final index = plans.indexWhere((p) => p.id == plan.id);
                                      if (index != -1) {
                                        plans[index] = PlanItem(
                                          id: plan.id,
                                          time: plan.time,
                                          title: plan.title,
                                          description: plan.description,
                                          location: newLocation,
                                        );
                                        _planService.saveDayPlans(_selectedDay, plans);
                                      }
                                    });
                                  }
                                },
                              ),
                            IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: () => _showAddPlanDialog(plan: plan),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete),
                              onPressed: () async {
                                final normalizedSelectedDay = DateTime(
                                  _selectedDay.year,
                                  _selectedDay.month,
                                  _selectedDay.day,
                                );
                                
                                setState(() {
                                  final plans = _getPlansForSelectedDay();
                                  plans.removeWhere((p) => p.id == plan.id);
                                  
                                  if (plans.isEmpty) {
                                    _planService.deleteDayPlans(normalizedSelectedDay);
                                    _plans.remove(normalizedSelectedDay);
                                  } else {
                                    _plans[normalizedSelectedDay] = plans;
                                    _planService.saveDayPlans(normalizedSelectedDay, plans);
                                  }
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
        ),
      ],
    );
  }

  void _showAddPlanDialog({PlanItem? plan}) {
    TimeOfDay initialTime;
    if (plan?.time != null && plan!.time.isNotEmpty) {
      try {
        final timeParts = plan.time.split(':');
        initialTime = TimeOfDay(
          hour: int.parse(timeParts[0]),
          minute: int.parse(timeParts[1]),
        );
      } catch (e) {
        initialTime = TimeOfDay.now();
      }
    } else {
      initialTime = TimeOfDay.now();
    }

    final timeController = TextEditingController(
      text: plan?.time ?? initialTime.format(context),
    );
    final titleController = TextEditingController(text: plan?.title ?? '');
    final descController = TextEditingController(text: plan?.description ?? '');
    LatLng? selectedLocation = plan?.location;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(plan == null ? 'Add Plan' : 'Edit Plan'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.access_time),
                  title: Text(timeController.text),
                  onTap: () async {
                    final TimeOfDay? picked = await showTimePicker(
                      context: context,
                      initialTime: initialTime,
                      builder: (BuildContext context, Widget? child) {
                        return MediaQuery(
                          data: MediaQuery.of(context).copyWith(
                            alwaysUse24HourFormat: false,
                          ),
                          child: child!,
                        );
                      },
                    );
                    if (picked != null) {
                      setDialogState(() {
                        final hour = picked.hour.toString().padLeft(2, '0');
                        final minute = picked.minute.toString().padLeft(2, '0');
                        timeController.text = '$hour:$minute';
                      });
                    }
                  },
                ),
                const Divider(),
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    icon: Icon(Icons.title),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    icon: Icon(Icons.description),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  icon: const Icon(Icons.location_on),
                  label: Text(selectedLocation != null ? 
                    'Change Location' : 'Add Location'),
                  onPressed: () async {
                    final result = await Navigator.push<LatLng>(
                      context,
                      MaterialPageRoute(
                        builder: (context) => GeoMapPage(
                          initialLocation: selectedLocation,
                          isSelectingLocation: true,
                        ),
                      ),
                    );
                    if (result != null) {
                      setDialogState(() {
                        selectedLocation = result;
                      });
                    }
                  },
                ),
                if (selectedLocation != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      'Location selected: ${selectedLocation!.latitude.toStringAsFixed(4)}, '
                      '${selectedLocation!.longitude.toStringAsFixed(4)}',
                      style: const TextStyle(color: Colors.green),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                if (titleController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a title')),
                  );
                  return;
                }

                final newPlan = PlanItem(
                  id: plan?.id ?? DateTime.now().toString(),
                  time: timeController.text,
                  title: titleController.text.trim(),
                  description: descController.text.trim(),
                  location: selectedLocation,
                );

                final normalizedSelectedDay = DateTime(
                  _selectedDay.year,
                  _selectedDay.month,
                  _selectedDay.day,
                );
                
                final plans = _getPlansForSelectedDay();
                if (plan != null) {
                  final index = plans.indexWhere((p) => p.id == plan.id);
                  if (index != -1) {
                    plans[index] = newPlan;
                  }
                } else {
                  plans.add(newPlan);
                }
                
                final sortedPlans = _sortPlansByTime(plans);

                Navigator.of(dialogContext).pop();

                _planService.saveDayPlans(normalizedSelectedDay, sortedPlans).then((_) {
                  if (mounted) {
                    setState(() {
                      _plans[normalizedSelectedDay] = sortedPlans;
                    });
                  }
                }).catchError((error) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Failed to save plan')),
                    );
                  }
                });
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}

class PlanItem {
  final String id;
  final String time;
  final String title;
  final String description;
  final LatLng? location;

  PlanItem({
    required this.id,
    required this.time,
    required this.title,
    required this.description,
    this.location,
  });
}
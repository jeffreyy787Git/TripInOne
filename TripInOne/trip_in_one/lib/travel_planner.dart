import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'geomap.dart';

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
    final plans = _plans[_selectedDay] ?? [];
    
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
                      _plans[_selectedDay] = plans;
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
                                      ),
                                    ),
                                  );
                                  
                                  if (newLocation != null) {
                                    setState(() {
                                      final plans = _plans[_selectedDay] ?? [];
                                      final index = plans.indexWhere((p) => p.id == plan.id);
                                      if (index != -1) {
                                        plans[index] = PlanItem(
                                          id: plan.id,
                                          time: plan.time,
                                          title: plan.title,
                                          description: plan.description,
                                          location: newLocation,
                                        );
                                        _plans[_selectedDay] = plans;
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
                              onPressed: () {
                                setState(() {
                                  final plans = _plans[_selectedDay] ?? [];
                                  plans.remove(plan);
                                  _plans[_selectedDay] = plans;
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
    final timeController = TextEditingController(text: plan?.time ?? '');
    final titleController = TextEditingController(text: plan?.title ?? '');
    final descController = TextEditingController(text: plan?.description ?? '');
    LatLng? selectedLocation = plan?.location;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(plan == null ? 'Add Plan' : 'Edit Plan'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: timeController,
                  decoration: const InputDecoration(
                    labelText: 'Time (e.g., 09:00)',
                  ),
                ),
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                  ),
                ),
                TextField(
                  controller: descController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
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
                        builder: (context) => const GeoMapPage(),
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
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                final newPlan = PlanItem(
                  id: plan?.id ?? DateTime.now().toString(),
                  time: timeController.text,
                  title: titleController.text,
                  description: descController.text,
                  location: selectedLocation,
                );

                setState(() {
                  final plans = _plans[_selectedDay] ?? [];
                  if (plan != null) {
                    final index = plans.indexWhere((p) => p.id == plan.id);
                    if (index != -1) {
                      plans[index] = newPlan;
                    }
                  } else {
                    plans.add(newPlan);
                  }
                  _plans[_selectedDay] = plans;
                });

                Navigator.pop(context);
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
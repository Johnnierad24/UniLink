import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/services/auth_provider.dart';

class SchedulePage extends StatefulWidget {
  const SchedulePage({super.key});

  @override
  State<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends State<SchedulePage> {
  List<dynamic> _schedule = [];
  List<dynamic> _campuses = [];
  bool _loading = true;
  String? _error;
  int _selectedCampusId = 0;
  int _selectedDay = DateTime.now().weekday - 1;

  final List<String> _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final auth = context.read<AuthProvider>();
      final role = auth.user?.role ?? 'student';
      final userId = auth.user?.id;

      String scheduleEndpoint = '/api/schedule/';
      if (role == 'lecturer') {
        scheduleEndpoint = '/api/schedule/?lecturer=$userId';
      }

      final resSchedule = await auth.authService.get(scheduleEndpoint);
      final resCampuses = await auth.authService.get('/api/campuses/');

      if (resSchedule.statusCode == 200 && resCampuses.statusCode == 200) {
        setState(() {
          _schedule = jsonDecode(resSchedule.body)['results'] ??
              jsonDecode(resSchedule.body);
          _campuses = jsonDecode(resCampuses.body)['results'] ??
              jsonDecode(resCampuses.body);
          _loading = false;
        });
      } else {
        setState(() {
          _error = 'Failed to load schedule';
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  bool get _isLecturer {
    try {
      final auth = context.read<AuthProvider>();
      return auth.user?.role == 'lecturer';
    } catch (_) {
      return false;
    }
  }

  List<dynamic> get _filteredSchedule {
    var filtered = _schedule.where((s) {
      try {
        final start = DateTime.parse(s['start_time']);
        return start.weekday == _selectedDay + 1;
      } catch (_) {
        return false;
      }
    }).toList();

    if (_selectedCampusId > 0) {
      filtered = filtered
          .where((s) => s['campus']?['id'] == _selectedCampusId)
          .toList();
    }

    filtered.sort((a, b) {
      try {
        final aStart = DateTime.parse(a['start_time']);
        final bStart = DateTime.parse(b['start_time']);
        return aStart.compareTo(bStart);
      } catch (_) {
        return 0;
      }
    });

    return filtered;
  }

  String _formatTime(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final dt = DateTime.parse(dateStr);
      return '${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }

  void _showPostponeDialog(dynamic entry) {
    final reasonCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.pause_circle, color: Colors.orange[700]),
            const SizedBox(width: 8),
            const Text('Postpone Class'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Postpone: ${entry['title'] ?? 'Class'}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              'Time: ${_formatTime(entry['start_time'])} - ${_formatTime(entry['end_time'])}',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonCtrl,
              decoration: const InputDecoration(
                labelText: 'Reason for postponement',
                hintText: 'e.g., Personal commitment, Medical leave...',
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);

              try {
                final auth = context.read<AuthProvider>();
                final res = await auth.authService.post(
                  '/api/schedule/${entry['id']}/postpone/',
                  body: {'reason': reasonCtrl.text},
                );

                if (res.statusCode == 200) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          const Icon(Icons.check_circle, color: Colors.white),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Class postponed successfully!',
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold)),
                                Text(
                                  'Students have been notified.',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color:
                                          Colors.white.withValues(alpha: 0.9)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      backgroundColor: Colors.green,
                      duration: const Duration(seconds: 4),
                    ),
                  );
                  _fetchData();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          const Icon(Icons.error, color: Colors.white),
                          const SizedBox(width: 8),
                          const Expanded(
                              child: Text('Failed to postpone class')),
                        ],
                      ),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        const Icon(Icons.error, color: Colors.white),
                        const SizedBox(width: 8),
                        Expanded(child: Text('Error: $e')),
                      ],
                    ),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Confirm Postponement'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _isLecturer ? 'My Schedule' : 'Timetable',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                decoration: const InputDecoration(
                  labelText: 'Campus',
                  prefixIcon: Icon(Icons.business),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                value: _selectedCampusId,
                items: [
                  const DropdownMenuItem(value: 0, child: Text('All Campuses')),
                  ..._campuses.map((c) => DropdownMenuItem(
                        value: c['id'] as int,
                        child: Text(c['name'] ?? 'Unknown'),
                      )),
                ],
                onChanged: (v) => setState(() => _selectedCampusId = v ?? 0),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 50,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: 7,
                  itemBuilder: (ctx, i) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(_days[i]),
                      selected: _selectedDay == i,
                      onSelected: (_) => setState(() => _selectedDay = i),
                      selectedColor: Theme.of(context).colorScheme.primary,
                      labelStyle: TextStyle(
                        color: _selectedDay == i ? Colors.white : null,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(
                      child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(_error!),
                        const SizedBox(height: 16),
                        FilledButton(
                            onPressed: _fetchData, child: const Text('Retry')),
                      ],
                    ))
                  : _filteredSchedule.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.event_busy,
                                  size: 64, color: Colors.grey[400]),
                              const SizedBox(height: 16),
                              Text(_isLecturer
                                  ? 'No classes scheduled for you'
                                  : 'No classes scheduled'),
                              const SizedBox(height: 8),
                              Text(
                                _days[_selectedDay],
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filteredSchedule.length,
                          itemBuilder: (ctx, i) => _ScheduleCard(
                            entry: _filteredSchedule[i],
                            formatTime: _formatTime,
                            isLecturer: _isLecturer,
                            onPostpone: () =>
                                _showPostponeDialog(_filteredSchedule[i]),
                          ),
                        ),
        ),
      ],
    );
  }
}

class _ScheduleCard extends StatelessWidget {
  const _ScheduleCard(
      {required this.entry,
      required this.formatTime,
      required this.isLecturer,
      required this.onPostpone});
  final dynamic entry;
  final String Function(String?) formatTime;
  final bool isLecturer;
  final VoidCallback onPostpone;

  String get title => entry['title'] ?? 'Class';
  String get courseCode => entry['course_code'] ?? '';
  String get room => entry['room'] ?? 'TBD';
  String get audience => entry['audience'] ?? 'All';
  String get lecturerName => entry['lecturer']?['username'] ?? '';
  String get department => entry['department']?['name'] ?? '';
  String get campusName => entry['campus']?['name'] ?? '';
  String get startTime => formatTime(entry['start_time']);
  String get endTime => formatTime(entry['end_time']);
  int get enrollmentCount => entry['enrollment_count'] ?? 0;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showDetails(context),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Text(startTime,
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary)),
                    Text('to',
                        style:
                            TextStyle(fontSize: 10, color: Colors.grey[600])),
                    Text(endTime, style: TextStyle(color: Colors.grey[600])),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (courseCode.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.purple[100],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(courseCode,
                            style: TextStyle(
                                color: Colors.purple[800],
                                fontSize: 11,
                                fontWeight: FontWeight.bold)),
                      ),
                    const SizedBox(height: 4),
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.room, size: 14, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(room,
                            style: TextStyle(
                                color: Colors.grey[600], fontSize: 13)),
                      ],
                    ),
                    if (isLecturer && department.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.school, size: 14, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Expanded(
                              child: Text(department,
                                  style: TextStyle(
                                      color: Colors.grey[600], fontSize: 13))),
                        ],
                      ),
                    ],
                    if (!isLecturer && lecturerName.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.person, size: 14, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Expanded(
                              child: Text(lecturerName,
                                  style: TextStyle(
                                      color: Colors.grey[600], fontSize: 13),
                                  overflow: TextOverflow.ellipsis)),
                        ],
                      ),
                    ],
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.people, size: 14, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text('$enrollmentCount students',
                            style: TextStyle(
                                color: Colors.grey[600], fontSize: 13)),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(audience.toUpperCase(),
                              style: TextStyle(
                                  color: Colors.blue[800], fontSize: 10)),
                        ),
                      ],
                    ),
                    if (isLecturer) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: onPostpone,
                          icon: const Icon(Icons.pause_circle, size: 18),
                          label: const Text('Postpone'),
                          style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.orange),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDetails(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 20),
            if (courseCode.isNotEmpty)
              Chip(
                  label: Text(courseCode,
                      style: const TextStyle(fontWeight: FontWeight.bold))),
            const SizedBox(height: 8),
            Text(title, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 16),
            _DetailRow(
                icon: Icons.access_time,
                label: 'Time',
                value: '$startTime - $endTime'),
            _DetailRow(icon: Icons.room, label: 'Room', value: room),
            _DetailRow(
                icon: Icons.business, label: 'Campus', value: campusName),
            if (isLecturer && department.isNotEmpty)
              _DetailRow(
                  icon: Icons.school, label: 'Department', value: department),
            if (!isLecturer && lecturerName.isNotEmpty)
              _DetailRow(
                  icon: Icons.person, label: 'Lecturer', value: lecturerName),
            _DetailRow(
                icon: Icons.people,
                label: 'Enrolled',
                value: '$enrollmentCount students'),
            _DetailRow(icon: Icons.groups, label: 'Audience', value: audience),
            if (isLecturer) ...[
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    onPostpone();
                  },
                  icon: const Icon(Icons.pause_circle),
                  label: const Text('Postpone This Class'),
                  style:
                      OutlinedButton.styleFrom(foregroundColor: Colors.orange),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow(
      {required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.bodySmall),
              Text(value, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ],
      ),
    );
  }
}

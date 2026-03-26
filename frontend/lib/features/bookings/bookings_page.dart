import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/services/auth_provider.dart';

class BookingsPage extends StatefulWidget {
  const BookingsPage({super.key});

  @override
  State<BookingsPage> createState() => _BookingsPageState();
}

class _BookingsPageState extends State<BookingsPage> {
  List<dynamic> _bookings = [];
  List<dynamic> _resources = [];
  bool _loading = true;
  String? _error;
  int _tabIndex = 0;

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
      final resBookings = await auth.authService.get('/api/bookings/');
      final resResources = await auth.authService.get('/api/resources/');

      if (resBookings.statusCode == 200 && resResources.statusCode == 200) {
        setState(() {
          _bookings = jsonDecode(resBookings.body)['results'] ??
              jsonDecode(resBookings.body);
          _resources = jsonDecode(resResources.body)['results'] ??
              jsonDecode(resResources.body);
          _loading = false;
        });
      } else {
        setState(() {
          _error = 'Failed to load data';
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

  String _formatDateTime(String? dateStr) {
    if (dateStr == null) return 'TBD';
    try {
      final dt = DateTime.parse(dateStr);
      return '${dt.day}/${dt.month}/${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return dateStr;
    }
  }

  void _showBookingDialog(dynamic resource) {
    final auth = context.read<AuthProvider>();
    final userRole = auth.user?.role ?? 'student';

    final studentAllowedTypes = ['study_room', 'collab_zone', 'laboratory'];
    if (userRole == 'student' &&
        !studentAllowedTypes.contains(resource['type'])) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Students can only book study rooms, collaboration zones, and laboratories.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final name = resource['name'] ?? 'Unknown';
    DateTime selectedDate = DateTime.now().add(const Duration(days: 1));
    TimeOfDay startTime = const TimeOfDay(hour: 9, minute: 0);
    TimeOfDay endTime = const TimeOfDay(hour: 11, minute: 0);
    final attendeesCtrl = TextEditingController(text: '1');
    final notesCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Book $name'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  resource['type']
                          ?.toString()
                          .replaceAll('_', ' ')
                          .toUpperCase() ??
                      '',
                  style: TextStyle(color: Colors.grey[600]),
                ),
                Text(resource['location'] ?? '',
                    style: TextStyle(color: Colors.grey[600])),
                const SizedBox(height: 16),
                const Text('Select Date'),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () async {
                    final date = await showDatePicker(
                      context: ctx,
                      initialDate: selectedDate,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 30)),
                    );
                    if (date != null) {
                      setDialogState(() => selectedDate = date);
                    }
                  },
                  icon: const Icon(Icons.calendar_today),
                  label: Text(
                      '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}'),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Start Time'),
                          const SizedBox(height: 8),
                          OutlinedButton(
                            onPressed: () async {
                              final time = await showTimePicker(
                                context: ctx,
                                initialTime: startTime,
                              );
                              if (time != null) {
                                setDialogState(() => startTime = time);
                              }
                            },
                            child: Text(startTime.format(ctx)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('End Time'),
                          const SizedBox(height: 8),
                          OutlinedButton(
                            onPressed: () async {
                              final time = await showTimePicker(
                                context: ctx,
                                initialTime: endTime,
                              );
                              if (time != null) {
                                setDialogState(() => endTime = time);
                              }
                            },
                            child: Text(endTime.format(ctx)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: attendeesCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Number of Attendees',
                    prefixIcon: Icon(Icons.people),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Notes (optional)',
                    prefixIcon: Icon(Icons.note),
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final startDateTime = DateTime(
                  selectedDate.year,
                  selectedDate.month,
                  selectedDate.day,
                  startTime.hour,
                  startTime.minute,
                );
                final endDateTime = DateTime(
                  selectedDate.year,
                  selectedDate.month,
                  selectedDate.day,
                  endTime.hour,
                  endTime.minute,
                );

                if (endDateTime.isBefore(startDateTime) ||
                    endDateTime.isAtSameMomentAs(startDateTime)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('End time must be after start time'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                try {
                  final auth = context.read<AuthProvider>();
                  final res =
                      await auth.authService.post('/api/bookings/', body: {
                    'resource': resource['id'],
                    'start_time': startDateTime.toIso8601String(),
                    'end_time': endDateTime.toIso8601String(),
                    'attendees': int.tryParse(attendeesCtrl.text) ?? 1,
                    'notes': notesCtrl.text,
                  });

                  if (res.statusCode == 201) {
                    if (mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content:
                              Text('Booking request submitted successfully!'),
                          backgroundColor: Colors.green,
                        ),
                      );
                      _fetchData();
                    }
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content:
                            Text('Failed to book: ${jsonDecode(res.body)}'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: const Text('Book'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _cancelBooking(int bookingId) async {
    try {
      final auth = context.read<AuthProvider>();
      final res = await auth.authService.patch(
        '/api/bookings/$bookingId/',
        body: {'status': 'cancelled'},
      );

      if (res.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Booking cancelled successfully'),
            backgroundColor: Colors.green,
          ),
        );
        _fetchData();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to cancel: ${jsonDecode(res.body)}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Booking',
                    style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 12),
                SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 0, label: Text('My Bookings')),
                    ButtonSegment(value: 1, label: Text('Resources')),
                  ],
                  selected: {_tabIndex},
                  onSelectionChanged: (s) =>
                      setState(() => _tabIndex = s.first),
                ),
              ],
            ),
          ),
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
                              onPressed: _fetchData,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : _tabIndex == 0
                        ? _bookings.isEmpty
                            ? const Center(child: Text('No bookings yet'))
                            : ListView.builder(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 16),
                                itemCount: _bookings.length,
                                itemBuilder: (ctx, i) => _BookingCard(
                                  booking: _bookings[i],
                                  formatDate: _formatDateTime,
                                  onCancel: () =>
                                      _cancelBooking(_bookings[i]['id']),
                                ),
                              )
                        : _resources.isEmpty
                            ? const Center(
                                child: Text('No resources available'))
                            : ListView.builder(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 16),
                                itemCount: _resources.length,
                                itemBuilder: (ctx, i) => _ResourceCard(
                                  resource: _resources[i],
                                  onBook: () =>
                                      _showBookingDialog(_resources[i]),
                                ),
                              ),
          ),
        ],
      ),
      floatingActionButton: _tabIndex == 1
          ? Builder(
              builder: (ctx) => FloatingActionButton(
                onPressed: () {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(
                      content: Text('Tap a resource to book it'),
                    ),
                  );
                },
                child: const Icon(Icons.add),
                tooltip: 'Book Resource',
              ),
            )
          : null,
    );
  }
}

class _BookingCard extends StatelessWidget {
  const _BookingCard(
      {required this.booking,
      required this.formatDate,
      required this.onCancel});
  final dynamic booking;
  final String Function(String?) formatDate;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final resourceName = booking['resource']?['name'] ?? 'Unknown';
    final resourceType =
        booking['resource']?['type']?.toString().replaceAll('_', ' ') ?? '';
    final resourceLocation = booking['resource']?['location'] ?? '';
    final status = booking['status'] ?? 'pending';
    final startTime = formatDate(booking['start_time']);
    final endTime = formatDate(booking['end_time']);
    final attendees = booking['attendees'] ?? 1;
    final isCancelled = status.toLowerCase() == 'cancelled';

    return Dismissible(
      key: Key(booking['id'].toString()),
      direction:
          isCancelled ? DismissDirection.none : DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text('Cancel Booking',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
            SizedBox(width: 8),
            Icon(Icons.delete, color: Colors.white),
          ],
        ),
      ),
      confirmDismiss: (direction) async {
        return await _showCancelConfirmation(context, resourceName);
      },
      onDismissed: (_) => onCancel(),
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _showBookingDetails(context),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor:
                          _statusColor(status).withValues(alpha: 0.3),
                      child: Icon(
                        _statusIcon(status),
                        color: _statusTextColor(status),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            resourceName,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          Text(
                            resourceType,
                            style: TextStyle(
                                color: Colors.grey[600], fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    Chip(
                      label: Text(status.toString().toUpperCase()),
                      backgroundColor: _statusColor(status),
                      labelStyle: TextStyle(
                        color: _statusTextColor(status),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.calendar_today,
                        size: 14, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(startTime,
                        style:
                            TextStyle(color: Colors.grey[600], fontSize: 13)),
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward,
                        size: 14, color: Colors.grey),
                    const SizedBox(width: 8),
                    Text(endTime,
                        style:
                            TextStyle(color: Colors.grey[600], fontSize: 13)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (resourceLocation.isNotEmpty) ...[
                      Icon(Icons.location_on,
                          size: 14, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          resourceLocation,
                          style:
                              TextStyle(color: Colors.grey[600], fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                    Icon(Icons.people, size: 14, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text('$attendees attendee${attendees > 1 ? 's' : ''}',
                        style:
                            TextStyle(color: Colors.grey[600], fontSize: 13)),
                  ],
                ),
                if (!isCancelled) ...[
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton.icon(
                        onPressed: () async {
                          final confirm = await _showCancelConfirmation(
                              context, resourceName);
                          if (confirm == true) onCancel();
                        },
                        icon: const Icon(Icons.cancel, size: 18),
                        label: const Text('Cancel'),
                        style:
                            TextButton.styleFrom(foregroundColor: Colors.red),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<bool?> _showCancelConfirmation(
      BuildContext context, String resourceName) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber, color: Colors.orange),
            SizedBox(width: 8),
            Text('Cancel Booking'),
          ],
        ),
        content: Text(
            'Are you sure you want to cancel your booking for "$resourceName"?\n\nThis action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep Booking'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Cancel Booking'),
          ),
        ],
      ),
    );
  }

  void _showBookingDetails(BuildContext context) {
    final resourceName = booking['resource']?['name'] ?? 'Unknown';
    final resourceType =
        booking['resource']?['type']?.toString().replaceAll('_', ' ') ?? '';
    final resourceLocation = booking['resource']?['location'] ?? '';
    final status = booking['status'] ?? 'pending';
    final startTime = formatDate(booking['start_time']);
    final endTime = formatDate(booking['end_time']);
    final attendees = booking['attendees'] ?? 1;
    final notes = booking['notes'] ?? 'No notes';

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
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: Text(
                    resourceName,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                Chip(
                  label: Text(status.toString().toUpperCase()),
                  backgroundColor: _statusColor(status),
                  labelStyle: TextStyle(
                    color: _statusTextColor(status),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _BookingDetailRow(
              icon: Icons.category,
              label: 'Type',
              value: resourceType,
            ),
            _BookingDetailRow(
              icon: Icons.location_on,
              label: 'Location',
              value:
                  resourceLocation.isEmpty ? 'Not specified' : resourceLocation,
            ),
            _BookingDetailRow(
              icon: Icons.calendar_today,
              label: 'Date',
              value: startTime.split(' ')[0],
            ),
            _BookingDetailRow(
              icon: Icons.access_time,
              label: 'Time',
              value: '${startTime.split(' ')[1]} - ${endTime.split(' ')[1]}',
            ),
            _BookingDetailRow(
              icon: Icons.people,
              label: 'Attendees',
              value: '$attendees',
            ),
            const SizedBox(height: 8),
            _BookingDetailRow(
              icon: Icons.note,
              label: 'Notes',
              value: notes,
            ),
            const SizedBox(height: 24),
            if (status.toLowerCase() != 'cancelled')
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    final confirm =
                        await _showCancelConfirmation(context, resourceName);
                    if (confirm == true) onCancel();
                  },
                  icon: const Icon(Icons.cancel),
                  label: const Text('Cancel This Booking'),
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                ),
              ),
          ],
        ),
      ),
    );
  }

  IconData _statusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'confirmed':
        return Icons.check_circle;
      case 'cancelled':
        return Icons.cancel;
      default:
        return Icons.pending;
    }
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'confirmed':
        return Colors.green[50]!;
      case 'cancelled':
        return Colors.red[50]!;
      default:
        return Colors.amber[50]!;
    }
  }

  Color _statusTextColor(String status) {
    switch (status.toLowerCase()) {
      case 'confirmed':
        return Colors.green[800]!;
      case 'cancelled':
        return Colors.red[800]!;
      default:
        return Colors.amber[800]!;
    }
  }
}

class _BookingDetailRow extends StatelessWidget {
  const _BookingDetailRow(
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

class _ResourceCard extends StatelessWidget {
  const _ResourceCard({required this.resource, required this.onBook});
  final dynamic resource;
  final VoidCallback onBook;

  @override
  Widget build(BuildContext context) {
    final name = resource['name'] ?? 'Unknown';
    final type = resource['type'] ?? '';
    final location = resource['location'] ?? '';
    final capacity = resource['capacity'] ?? 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          child: Icon(_typeIcon(type)),
        ),
        title: Text(name),
        subtitle:
            Text('${type.replaceAll('_', ' ')} • $location • $capacity seats'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Chip(label: Text('Available')),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.add_circle, color: Colors.blue),
              onPressed: onBook,
              tooltip: 'Book this resource',
            ),
          ],
        ),
      ),
    );
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'laboratory':
        return Icons.science;
      case 'study_room':
        return Icons.meeting_room;
      case 'lecture_hall':
        return Icons.meeting_room;
      case 'collab_zone':
        return Icons.groups;
      default:
        return Icons.room;
    }
  }
}

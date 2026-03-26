import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/services/auth_provider.dart';

class EventsPage extends StatefulWidget {
  const EventsPage({super.key});

  @override
  State<EventsPage> createState() => _EventsPageState();
}

class _EventsPageState extends State<EventsPage> {
  List<dynamic> _events = [];
  List<dynamic> _campuses = [];
  bool _loading = true;
  String? _error;
  String _search = '';
  String? _selectedCategory;
  int? _selectedCampusId;

  @override
  void initState() {
    super.initState();
    _fetchEvents();
  }

  Future<void> _fetchEvents() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final auth = context.read<AuthProvider>();
      final query = <String, String>{};
      if (_search.isNotEmpty) query['search'] = _search;
      if (_selectedCategory != null) query['category'] = _selectedCategory!;
      if (_selectedCampusId != null)
        query['campus'] = _selectedCampusId.toString();

      final res = await auth.authService
          .get('/api/events/', query: query.isEmpty ? null : query);

      final resCampuses = await auth.authService.get('/api/campuses/');
      if (resCampuses.statusCode == 200) {
        _campuses = jsonDecode(resCampuses.body)['results'] ??
            jsonDecode(resCampuses.body);
      }

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          _events = data['results'] ?? data;
          _loading = false;
        });
      } else {
        setState(() {
          _error = 'Failed to load events';
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

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Campus Discovery',
                  style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                decoration: const InputDecoration(
                  labelText: 'Filter by Campus',
                  prefixIcon: Icon(Icons.business),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                value: _selectedCampusId,
                items: [
                  const DropdownMenuItem(
                      value: null, child: Text('All Campuses')),
                  ..._campuses.map((c) => DropdownMenuItem(
                        value: c['id'] as int,
                        child: Text(c['name'] ?? 'Unknown'),
                      )),
                ],
                onChanged: (v) {
                  setState(() => _selectedCampusId = v);
                  _fetchEvents();
                },
              ),
              const SizedBox(height: 12),
              TextField(
                decoration: InputDecoration(
                  hintText: 'Search events...',
                  prefixIcon: const Icon(Icons.search),
                ),
                onChanged: (v) => _search = v,
                onSubmitted: (_) => _fetchEvents(),
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    FilterChip(
                      label: const Text('All'),
                      selected: _selectedCategory == null,
                      onSelected: (_) {
                        setState(() => _selectedCategory = null);
                        _fetchEvents();
                      },
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: const Text('Academic'),
                      selected: _selectedCategory == 'academic',
                      onSelected: (_) {
                        setState(() => _selectedCategory = 'academic');
                        _fetchEvents();
                      },
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: const Text('Social'),
                      selected: _selectedCategory == 'social',
                      onSelected: (_) {
                        setState(() => _selectedCategory = 'social');
                        _fetchEvents();
                      },
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: const Text('Sports'),
                      selected: _selectedCategory == 'sports',
                      onSelected: (_) {
                        setState(() => _selectedCategory = 'sports');
                        _fetchEvents();
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(child: Text(_error!))
                  : _events.isEmpty
                      ? const Center(child: Text('No events found'))
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _events.length,
                          itemBuilder: (ctx, i) =>
                              _EventCard(event: _events[i]),
                        ),
        ),
      ],
    );
  }
}

class _EventCard extends StatelessWidget {
  const _EventCard({required this.event});
  final dynamic event;

  bool _isStudent(BuildContext context) {
    try {
      final auth = context.read<AuthProvider>();
      return auth.user?.role == 'student';
    } catch (_) {
      return false;
    }
  }

  bool _isLecturerInvited(BuildContext context) {
    try {
      final auth = context.read<AuthProvider>();
      final username = auth.user?.username ?? '';
      final guests = event['guests'] as List? ?? [];
      final patrons = event['patrons'] as List? ?? [];
      return guests.any((g) => g['username'] == username) ||
          patrons.any((p) => p['username'] == username);
    } catch (_) {
      return false;
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return 'TBD';
    try {
      final dt = DateTime.parse(dateStr);
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return dateStr;
    }
  }

  String _formatDateTime(String? dateStr) {
    if (dateStr == null) return 'TBD';
    try {
      final dt = DateTime.parse(dateStr);
      return '${dt.day}/${dt.month}/${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return 'Invalid date';
    }
  }

  void _showEventDetails(BuildContext context) {
    final title = event['title'] ?? '';
    final description = event['description'] ?? 'No description available';
    final location = event['location'] ?? 'TBD';
    final category = event['category'] ?? 'Other';
    final startTime = event['start_time'];
    final endTime = event['end_time'];
    final campus = event['campus']?['name'] ?? 'TBD';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(24),
          child: Column(
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
              Chip(label: Text(category.toString().toUpperCase())),
              const SizedBox(height: 12),
              Text(title, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 16),
              _DetailRow(
                  icon: Icons.location_on, label: 'Location', value: location),
              _DetailRow(icon: Icons.business, label: 'Campus', value: campus),
              _DetailRow(
                  icon: Icons.calendar_today,
                  label: 'Start',
                  value: _formatDateTime(startTime)),
              if (endTime != null)
                _DetailRow(
                    icon: Icons.access_time,
                    label: 'End',
                    value: _formatDateTime(endTime)),
              const SizedBox(height: 16),
              Text('Description',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(description),
              const SizedBox(height: 24),
              if (_isStudent(context))
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _showRegistrationDialog(context);
                    },
                    child: const Text('Register for this Event'),
                  ),
                )
              else if (_isLecturerInvited(context))
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _acceptInvitation(context);
                    },
                    icon: const Icon(Icons.check_circle),
                    label: const Text('Accept Invitation'),
                    style:
                        FilledButton.styleFrom(backgroundColor: Colors.green),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _acceptInvitation(BuildContext context) {
    final title = event['title'] ?? 'this event';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Text('Accept Invitation'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('You have been invited to attend:'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Would you like to accept this invitation?'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Decline'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      const Icon(Icons.check_circle, color: Colors.white),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text(
                              'Invitation accepted! You are attending: $title')),
                    ],
                  ),
                  backgroundColor: Colors.green,
                  duration: const Duration(seconds: 3),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              );
            },
            child: const Text('Accept Invitation'),
          ),
        ],
      ),
    );
  }

  void _showRegistrationDialog(BuildContext context) {
    final title = event['title'] ?? 'this event';
    final formKey = GlobalKey<FormState>();
    final fullNameCtrl = TextEditingController();
    final schoolIdCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.how_to_reg, color: Colors.green),
            SizedBox(width: 8),
            Text('Event Registration'),
          ],
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.event, color: Colors.blue, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: fullNameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Full Name *',
                  hintText: 'Enter your full name',
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (v) =>
                    v == null || v.isEmpty ? 'Full name is required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: schoolIdCtrl,
                decoration: const InputDecoration(
                  labelText: 'School ID *',
                  hintText: 'e.g., CT203/205623/25',
                  prefixIcon: Icon(Icons.badge),
                ),
                validator: (v) =>
                    v == null || v.isEmpty ? 'School ID is required' : null,
              ),
              const SizedBox(height: 8),
              Text(
                '* Required fields',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
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
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.pop(ctx);
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
                              const Text('Registration Successful!',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold)),
                              Text(
                                  '${fullNameCtrl.text} registered for $title'),
                            ],
                          ),
                        ),
                      ],
                    ),
                    backgroundColor: Colors.green,
                    duration: const Duration(seconds: 2),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                );
              }
            },
            child: const Text('Confirm Registration'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = event['title'] ?? '';
    final location = event['location'] ?? 'TBD';
    final category = event['category'] ?? 'Other';
    final startTime = event['start_time'];

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                    child: Text(title,
                        style: Theme.of(context).textTheme.titleMedium)),
                Chip(label: Text(category.toString().toUpperCase())),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.calendar_today, size: 16),
                const SizedBox(width: 4),
                Text(_formatDate(startTime)),
                const SizedBox(width: 12),
                const Icon(Icons.location_on, size: 16),
                const SizedBox(width: 4),
                Expanded(
                    child: Text(location, overflow: TextOverflow.ellipsis)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => _showEventDetails(context),
                  child: const Text('View Details'),
                ),
                if (_isStudent(context)) ...[
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () => _showRegistrationDialog(context),
                    child: const Text('Register'),
                  ),
                ],
                if (_isLecturerInvited(context)) ...[
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: () => _acceptInvitation(context),
                    icon: const Icon(Icons.check_circle, size: 18),
                    label: const Text('Accept'),
                    style:
                        FilledButton.styleFrom(backgroundColor: Colors.green),
                  ),
                ],
              ],
            ),
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
      padding: const EdgeInsets.symmetric(vertical: 4),
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

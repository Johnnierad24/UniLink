import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/services/auth_provider.dart';
import '../../core/widgets/unilink_logo.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  List<dynamic> _announcements = [];
  List<dynamic> _upcomingEvents = [];
  List<dynamic> _campuses = [];
  dynamic _nextBooking;
  bool _loading = true;
  String? _error;
  int? _selectedCampusId;

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
      final queryAnnouncements = <String, String>{};
      final queryEvents = <String, String>{'page_size': '5'};
      if (_selectedCampusId != null) {
        queryAnnouncements['campus'] = _selectedCampusId.toString();
        queryEvents['campus'] = _selectedCampusId.toString();
      }

      final resAnnouncements = await auth.authService.get('/api/announcements/',
          query: queryAnnouncements.isEmpty ? null : queryAnnouncements);
      final resEvents =
          await auth.authService.get('/api/events/', query: queryEvents);
      final resBookings = await auth.authService
          .get('/api/bookings/', query: {'page_size': '1'});
      final resCampuses = await auth.authService.get('/api/campuses/');

      if (resAnnouncements.statusCode == 200 &&
          resEvents.statusCode == 200 &&
          resBookings.statusCode == 200 &&
          resCampuses.statusCode == 200) {
        setState(() {
          _announcements = (jsonDecode(resAnnouncements.body)['results'] ??
                  jsonDecode(resAnnouncements.body))
              .take(5)
              .toList();
          _upcomingEvents = (jsonDecode(resEvents.body)['results'] ??
                  jsonDecode(resEvents.body))
              .take(3)
              .toList();
          _campuses = jsonDecode(resCampuses.body)['results'] ??
              jsonDecode(resCampuses.body);
          final bookings = jsonDecode(resBookings.body)['results'] ??
              jsonDecode(resBookings.body);
          _nextBooking = bookings.isNotEmpty ? bookings.first : null;
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

  void _showCampusFilter() {
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
            Text('Filter by Campus',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.public),
              title: const Text('All Campuses'),
              selected: _selectedCampusId == null,
              onTap: () {
                setState(() => _selectedCampusId = null);
                Navigator.pop(ctx);
                _fetchData();
              },
            ),
            ..._campuses.map((c) => ListTile(
                  leading: const Icon(Icons.business),
                  title: Text(c['name'] ?? 'Unknown'),
                  selected: _selectedCampusId == c['id'],
                  onTap: () {
                    setState(() => _selectedCampusId = c['id'] as int);
                    Navigator.pop(ctx);
                    _fetchData();
                  },
                )),
          ],
        ),
      ),
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
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

  void _showAnnouncementDetails(dynamic announcement) {
    final title = announcement['title'] ?? '';
    final body = announcement['body'] ?? 'No content';
    final isUrgent = announcement['is_urgent'] ?? false;
    final campus = announcement['campus']?['name'] ?? 'All Campuses';
    final publishedAt = announcement['published_at'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.5,
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
              if (isUrgent)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.red[100],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.warning, color: Colors.red[700], size: 18),
                      const SizedBox(width: 4),
                      Text(
                        'URGENT',
                        style: TextStyle(
                          color: Colors.red[700],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              if (isUrgent) const SizedBox(height: 12),
              Text(title, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.business, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(campus, style: TextStyle(color: Colors.grey[600])),
                  const SizedBox(width: 16),
                  Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    _formatDateTime(publishedAt),
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 16),
              Text(
                body,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final username = auth.user?.username ?? 'User';

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_error!),
            const SizedBox(height: 16),
            FilledButton(onPressed: _fetchData, child: const Text('Retry')),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${_getGreeting()}, $username',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text('Your academic day at a glance.',
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
              const UniLinkLogo(size: 48),
            ],
          ),
          if (_nextBooking != null) ...[
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                leading: const Icon(Icons.timer),
                title: Text(
                    'Next Booking: ${_nextBooking['resource']?['name'] ?? 'Unknown'}'),
                subtitle: Text(
                    '${_formatDateTime(_nextBooking['start_time'])} - ${_formatDateTime(_nextBooking['end_time'])}'),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text('Announcements',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: _showCampusFilter,
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.filter_list,
                            size: 16,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _selectedCampusId == null
                                ? 'All'
                                : _campuses
                                        .where(
                                            (c) => c['id'] == _selectedCampusId)
                                        .map((c) => c['name'] ?? 'Campus')
                                        .firstOrNull ??
                                    'Campus',
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              if (_announcements.any((a) => a['is_urgent'] == true))
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.red[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                      '${_announcements.where((a) => a['is_urgent'] == true).length} new',
                      style: TextStyle(color: Colors.red[700], fontSize: 12)),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (_announcements.isEmpty)
            Card(
              child: ListTile(
                leading: Icon(Icons.info_outline, color: Colors.grey[400]),
                title: const Text('No announcements'),
              ),
            )
          else
            ...List.generate(
              _announcements.length,
              (i) {
                final announcement = _announcements[i];
                final isUrgent = announcement['is_urgent'] ?? false;
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor:
                          isUrgent ? Colors.red[100] : Colors.blue[100],
                      child: Icon(Icons.campaign,
                          color: isUrgent ? Colors.red : Colors.blue),
                    ),
                    title: Text(announcement['title'] ?? ''),
                    subtitle: Text(announcement['body'] ?? '',
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _showAnnouncementDetails(announcement),
                  ),
                );
              },
            ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Upcoming Events',
                  style: Theme.of(context).textTheme.titleMedium),
              InkWell(
                onTap: _showCampusFilter,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.filter_list,
                        size: 16,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _selectedCampusId == null
                            ? 'All'
                            : _campuses
                                    .where((c) => c['id'] == _selectedCampusId)
                                    .map((c) => c['name'] ?? 'Campus')
                                    .firstOrNull ??
                                'Campus',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_upcomingEvents.isEmpty)
            Card(
              child: ListTile(
                leading: Icon(Icons.event_busy, color: Colors.grey[400]),
                title: const Text('No upcoming events'),
              ),
            )
          else
            ...List.generate(
              _upcomingEvents.length,
              (i) {
                final event = _upcomingEvents[i];
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                        backgroundColor: Colors.green[100],
                        child: const Icon(Icons.event, color: Colors.green)),
                    title: Text(event['title'] ?? ''),
                    subtitle: Text(_formatDateTime(event['start_time'])),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

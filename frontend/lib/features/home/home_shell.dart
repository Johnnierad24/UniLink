import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/widgets/unilink_logo.dart';
import '../../core/services/auth_provider.dart';
import '../dashboard/dashboard_page.dart';
import '../events/events_page.dart';
import '../bookings/bookings_page.dart';
import '../procurement/procurement_page.dart';
import '../schedule/schedule_page.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  List<dynamic> _notifications = [];

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  List<NavigationDestination> _getDestinations() {
    final auth = context.read<AuthProvider>();
    final role = auth.user?.role ?? 'student';
    final isStaffOrAdmin = role == 'staff' || role == 'admin';

    final destinations = <NavigationDestination>[
      const NavigationDestination(
        icon: Icon(Icons.home_outlined),
        selectedIcon: Icon(Icons.home),
        label: 'Home',
      ),
      const NavigationDestination(
        icon: Icon(Icons.event_note_outlined),
        selectedIcon: Icon(Icons.event),
        label: 'Events',
      ),
      const NavigationDestination(
        icon: Icon(Icons.layers_outlined),
        selectedIcon: Icon(Icons.layers),
        label: 'Booking',
      ),
      const NavigationDestination(
        icon: Icon(Icons.schedule_outlined),
        selectedIcon: Icon(Icons.schedule),
        label: 'Schedule',
      ),
    ];

    if (isStaffOrAdmin) {
      destinations.add(const NavigationDestination(
        icon: Icon(Icons.shopping_cart_outlined),
        selectedIcon: Icon(Icons.shopping_cart),
        label: 'Procure',
      ));
    }

    return destinations;
  }

  Widget _getPage(int index) {
    switch (index) {
      case 0:
        return const DashboardPage();
      case 1:
        return const EventsPage();
      case 2:
        return const BookingsPage();
      case 3:
        return const SchedulePage();
      case 4:
        return const ProcurementPage();
      default:
        return const DashboardPage();
    }
  }

  Future<void> _fetchNotifications() async {
    try {
      final auth = context.read<AuthProvider>();
      final resAnnouncements = await auth.authService
          .get('/api/announcements/', query: {'is_urgent': 'true'});
      final resEvents = await auth.authService.get('/api/events/');

      if (resAnnouncements.statusCode == 200 && resEvents.statusCode == 200) {
        final announcements = (jsonDecode(resAnnouncements.body)['results'] ??
                jsonDecode(resAnnouncements.body))
            .where((a) => a['is_urgent'] == true)
            .toList();
        final events = (jsonDecode(resEvents.body)['results'] ??
                jsonDecode(resEvents.body))
            .where((e) {
          final now = DateTime.now();
          try {
            final start = DateTime.parse(e['start_time']);
            return start.isAfter(now.subtract(const Duration(hours: 24)));
          } catch (_) {
            return false;
          }
        }).toList();

        setState(() {
          _notifications = [...announcements, ...events];
        });
      }
    } catch (_) {}
  }

  void _showNotifications() {
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
        builder: (_, scrollController) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.notifications),
                  const SizedBox(width: 8),
                  Text('Notifications',
                      style: Theme.of(context).textTheme.titleLarge),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _fetchNotifications();
                    },
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: _notifications.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.notifications_off,
                              size: 48, color: Colors.grey),
                          SizedBox(height: 16),
                          Text('No urgent notifications'),
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: scrollController,
                      itemCount: _notifications.length,
                      itemBuilder: (ctx, i) =>
                          _NotificationTile(notification: _notifications[i]),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Logout')),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await context.read<AuthProvider>().logout();
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<AuthProvider>();
    final urgentCount = _notifications.length;
    final destinations = _getDestinations();

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: const [
            UniLinkLogo(size: 32),
            SizedBox(width: 12),
            Text('UniLink'),
          ],
        ),
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_none),
                onPressed: _showNotifications,
              ),
              if (urgentCount > 0)
                Positioned(
                  right: 6,
                  top: 6,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    constraints:
                        const BoxConstraints(minWidth: 18, minHeight: 18),
                    child: Text(
                      urgentCount > 9 ? '9+' : urgentCount.toString(),
                      style: const TextStyle(color: Colors.white, fontSize: 10),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      body: _getPage(_index),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index.clamp(0, destinations.length - 1),
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: destinations,
      ),
      floatingActionButton: _index == 1
          ? FloatingActionButton(
              onPressed: () {},
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification});
  final dynamic notification;

  bool get isAnnouncement => notification.containsKey('body');

  String get title => notification['title'] ?? 'Notification';
  String get body => notification['body'] ?? '';
  bool get isUrgent => notification['is_urgent'] ?? false;
  String? get startTime => notification['start_time'];

  String _formatDateTime(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final dt = DateTime.parse(dateStr);
      return '${dt.day}/${dt.month} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: isAnnouncement ? Colors.red[100] : Colors.orange[100],
        child: Icon(
          isAnnouncement ? Icons.campaign : Icons.event,
          color: isAnnouncement ? Colors.red : Colors.orange,
          size: 20,
        ),
      ),
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (body.isNotEmpty)
            Text(body, maxLines: 2, overflow: TextOverflow.ellipsis),
          if (startTime != null)
            Text(_formatDateTime(startTime),
                style: TextStyle(color: Colors.grey[600], fontSize: 12)),
        ],
      ),
      trailing: isUrgent
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                  color: Colors.red[100],
                  borderRadius: BorderRadius.circular(8)),
              child: Text('URGENT',
                  style: TextStyle(
                      color: Colors.red[700],
                      fontSize: 10,
                      fontWeight: FontWeight.bold)),
            )
          : null,
      isThreeLine: body.isNotEmpty && startTime != null,
      onTap: () => _showNotificationDetails(context),
    );
  }

  void _showNotificationDetails(BuildContext context) {
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
                CircleAvatar(
                  backgroundColor:
                      isAnnouncement ? Colors.red[100] : Colors.orange[100],
                  child: Icon(
                    isAnnouncement ? Icons.campaign : Icons.event,
                    color: isAnnouncement ? Colors.red : Colors.orange,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(isAnnouncement ? 'Announcement' : 'Event',
                          style:
                              TextStyle(color: Colors.grey[600], fontSize: 12)),
                      Text(title,
                          style: Theme.of(context).textTheme.titleMedium),
                    ],
                  ),
                ),
                if (isUrgent)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('URGENT',
                        style: TextStyle(
                            color: Colors.red[700],
                            fontSize: 11,
                            fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (body.isNotEmpty) ...[
              Text('Details', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              Text(body),
              const SizedBox(height: 16),
            ],
            if (startTime != null) ...[
              Row(
                children: [
                  Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Text(_formatDateTime(startTime),
                      style: TextStyle(color: Colors.grey[600])),
                ],
              ),
            ],
            if (!isAnnouncement && notification['location'] != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Text(notification['location'] ?? '',
                          style: TextStyle(color: Colors.grey[600]))),
                ],
              ),
            ],
            if (!isAnnouncement && notification['campus'] != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.business, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Text(notification['campus']?['name'] ?? '',
                          style: TextStyle(color: Colors.grey[600]))),
                ],
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: isAnnouncement
                  ? const SizedBox()
                  : FilledButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('View Full Details'),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

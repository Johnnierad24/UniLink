import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/services/auth_provider.dart';

class ProcurementPage extends StatefulWidget {
  const ProcurementPage({super.key});

  @override
  State<ProcurementPage> createState() => _ProcurementPageState();
}

class _ProcurementPageState extends State<ProcurementPage> {
  List<dynamic> _requests = [];
  List<dynamic> _events = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchRequests();
  }

  Future<void> _fetchRequests() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final auth = context.read<AuthProvider>();
      final res = await auth.authService.get('/api/procurements/');
      final resEvents = await auth.authService.get('/api/events/');

      if (res.statusCode == 200) {
        setState(() {
          _requests = jsonDecode(res.body)['results'] ?? jsonDecode(res.body);
          if (resEvents.statusCode == 200) {
            _events = jsonDecode(resEvents.body)['results'] ??
                jsonDecode(resEvents.body);
          }
          _loading = false;
        });
      } else {
        setState(() {
          _error = 'Failed to load requests';
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

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return Colors.green[100]!;
      case 'rejected':
        return Colors.red[100]!;
      default:
        return Colors.amber[100]!;
    }
  }

  void _showCreateRequestDialog() {
    final titleCtrl = TextEditingController();
    final descriptionCtrl = TextEditingController();
    final costCtrl = TextEditingController();
    final reasonCtrl = TextEditingController();
    String priority = 'standard';
    dynamic selectedEvent;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.shopping_cart),
              SizedBox(width: 8),
              Text('New Procurement Request'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Submit a purchase request to the Procurement Office at Main Campus.',
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Item/Service Name *',
                    hintText: 'e.g., Microscope Slides x50',
                    prefixIcon: Icon(Icons.inventory),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descriptionCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    hintText: 'Detailed specifications...',
                    prefixIcon: Icon(Icons.description),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: costCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Estimated Cost (KSH) *',
                    hintText: '45000',
                    prefixIcon: Icon(Icons.attach_money),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                const Text('Priority Level'),
                const SizedBox(height: 8),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'standard', label: Text('Standard')),
                    ButtonSegment(value: 'urgent', label: Text('Urgent')),
                    ButtonSegment(value: 'critical', label: Text('Critical')),
                  ],
                  selected: {priority},
                  onSelectionChanged: (s) {
                    setDialogState(() => priority = s.first);
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<dynamic>(
                  decoration: const InputDecoration(
                    labelText: 'Link to Event (optional)',
                    prefixIcon: Icon(Icons.event),
                  ),
                  value: selectedEvent,
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('None'),
                    ),
                    ..._events.map((e) => DropdownMenuItem(
                          value: e,
                          child: Text(e['title'] ?? 'Unknown'),
                        )),
                  ],
                  onChanged: (v) {
                    setDialogState(() => selectedEvent = v);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: reasonCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Justification/Reason',
                    hintText: 'Why is this purchase needed?',
                    prefixIcon: Icon(Icons.question_mark),
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
            FilledButton.icon(
              onPressed: () async {
                if (titleCtrl.text.isEmpty || costCtrl.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please fill in required fields'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                try {
                  final auth = context.read<AuthProvider>();
                  final body = {
                    'title': titleCtrl.text,
                    'description': descriptionCtrl.text,
                    'estimated_cost': double.parse(costCtrl.text),
                    'priority': priority,
                    'reason': reasonCtrl.text,
                    if (selectedEvent != null)
                      'linked_event': selectedEvent['id'],
                  };

                  final res = await auth.authService
                      .post('/api/procurements/', body: body);

                  if (res.statusCode == 201) {
                    if (mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                              'Procurement request submitted successfully!'),
                          backgroundColor: Colors.green,
                        ),
                      );
                      _fetchRequests();
                    }
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed: ${jsonDecode(res.body)}'),
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
              icon: const Icon(Icons.send),
              label: const Text('Submit Request'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Procurement',
                          style: Theme.of(context).textTheme.headlineMedium),
                      const SizedBox(height: 4),
                      Text(
                        'Request purchases from Main Campus',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _fetchRequests,
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
                              onPressed: _fetchRequests,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : _requests.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.inbox,
                                    size: 64, color: Colors.grey[400]),
                                const SizedBox(height: 16),
                                const Text('No procurement requests'),
                                const SizedBox(height: 8),
                                FilledButton.icon(
                                  onPressed: _showCreateRequestDialog,
                                  icon: const Icon(Icons.add),
                                  label: const Text('Create Request'),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: _requests.length,
                            itemBuilder: (ctx, i) => _ProcurementTile(
                              request: _requests[i],
                              statusColor: _statusColor,
                            ),
                          ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateRequestDialog,
        icon: const Icon(Icons.add),
        label: const Text('New Request'),
      ),
    );
  }
}

class _ProcurementTile extends StatelessWidget {
  const _ProcurementTile({required this.request, required this.statusColor});
  final dynamic request;
  final Color Function(String) statusColor;

  String _formatAmount(dynamic amount) {
    if (amount == null) return 'KSH 0.00';
    try {
      return 'KSH ${double.parse(amount.toString()).toStringAsFixed(2)}';
    } catch (_) {
      return 'KSH $amount';
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = request['title'] ?? 'Unknown';
    final description = request['description'] ?? '';
    final status = request['status'] ?? 'pending';
    final amount = _formatAmount(request['estimated_cost']);
    final priority = request['priority'] ?? 'standard';
    final requestedBy = request['requested_by']?['username'] ?? 'Unknown';
    final linkedEvent = request['linked_event']?['title'];

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showRequestDetails(context),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(title,
                        style: Theme.of(context).textTheme.titleMedium),
                  ),
                  _PriorityBadge(priority: priority),
                ],
              ),
              const SizedBox(height: 8),
              if (description.isNotEmpty)
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodySmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.person, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    requestedBy,
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                  if (linkedEvent != null) ...[
                    const SizedBox(width: 16),
                    Icon(Icons.event, size: 14, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        linkedEvent,
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(amount,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  Chip(
                    label: Text(status.toString().toUpperCase()),
                    backgroundColor: statusColor(status),
                    labelStyle: const TextStyle(fontSize: 11),
                    padding: EdgeInsets.zero,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showRequestDetails(BuildContext context) {
    final title = request['title'] ?? 'Unknown';
    final description = request['description'] ?? 'No description';
    final status = request['status'] ?? 'pending';
    final amount = _formatAmount(request['estimated_cost']);
    final priority = request['priority'] ?? 'standard';
    final reason = request['reason'] ?? 'No justification provided';
    final requestedBy = request['requested_by']?['username'] ?? 'Unknown';
    final linkedEvent = request['linked_event']?['title'];

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
              Row(
                children: [
                  _PriorityBadge(priority: priority),
                  const Spacer(),
                  Chip(
                    label: Text(status.toString().toUpperCase()),
                    backgroundColor: statusColor(status),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(title, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(amount,
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 18)),
              const SizedBox(height: 20),
              _DetailRow(
                  icon: Icons.person,
                  label: 'Requested By',
                  value: requestedBy),
              _DetailRow(
                  icon: Icons.category,
                  label: 'Priority',
                  value: priority.toUpperCase()),
              if (linkedEvent != null)
                _DetailRow(
                    icon: Icons.event,
                    label: 'Linked Event',
                    value: linkedEvent),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),
              Text('Description',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(description),
              const SizedBox(height: 16),
              Text('Justification',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(reason),
            ],
          ),
        ),
      ),
    );
  }
}

class _PriorityBadge extends StatelessWidget {
  const _PriorityBadge({required this.priority});
  final String priority;

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (priority.toLowerCase()) {
      case 'critical':
        color = Colors.red;
        break;
      case 'urgent':
        color = Colors.orange;
        break;
      default:
        color = Colors.blue;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (priority.toLowerCase() != 'standard')
            Icon(Icons.warning, size: 14, color: color),
          if (priority.toLowerCase() != 'standard') const SizedBox(width: 4),
          Text(
            priority.toUpperCase(),
            style: TextStyle(
                color: color, fontWeight: FontWeight.bold, fontSize: 11),
          ),
        ],
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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:iconly/iconly.dart';
import '../../providers/providers.dart';
import '../../core/constants.dart';
import '../../core/firebase_functions_config.dart';
import '../../models/admin_action_model.dart';

class AdminActionsScreen extends ConsumerStatefulWidget {
  const AdminActionsScreen({super.key});

  @override
  ConsumerState<AdminActionsScreen> createState() => _AdminActionsScreenState();
}

class _AdminActionsScreenState extends ConsumerState<AdminActionsScreen> {
  String _selectedFilter = 'all';
  final _searchController = TextEditingController();
  String _searchQuery = '';
  Map<String, String> _userIdToNameMap = {};
  bool _isLoadingUsers = true;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    try {
      final users = await ref.read(firestoreServiceProvider).getAllUsers();
      setState(() {
        _userIdToNameMap = {
          for (var user in users) user.uid: user.displayName,
        };
        _isLoadingUsers = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingUsers = false;
      });
      // Silently fail - we'll just show user IDs if we can't load names
    }
  }

  Future<void> _refreshData() async {
    // Invalidate the provider to refresh the stream
    ref.invalidate(firestoreServiceProvider);
    await Future.delayed(const Duration(milliseconds: 300));
  }

  @override
  Widget build(BuildContext context) {
    final adminActionsStream =
        ref.watch(firestoreServiceProvider).streamAdminActions(limit: 100);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Actions Log'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(140),
          child: Column(
            children: [
              // Search bar
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    hintText: 'Search by action or player...',
                    prefixIcon: Icon(IconlyLight.search),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  onChanged: (value) {
                    setState(() => _searchQuery = value.toLowerCase());
                  },
                ),
              ),
              // Filter chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    _buildFilterChip('all', 'All Actions'),
                    _buildFilterChip('createGame', 'Game Creation'),
                    _buildFilterChip('deleteGame', 'Deletions'),
                    _buildFilterChip('startBattle', 'Battle Control'),
                    _buildFilterChip('sendReminder', 'Notifications'),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
      body: StreamBuilder<List<AdminAction>>(
        stream: adminActionsStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          var actions = snapshot.data!;

          // Apply filters
          if (_selectedFilter != 'all') {
            actions =
                actions.where((a) => a.actionType == _selectedFilter).toList();
          }

          // Apply search
          if (_searchQuery.isNotEmpty) {
            actions = actions
                .where((a) =>
                    a.actionDescription.toLowerCase().contains(_searchQuery) ||
                    a.actionType.toLowerCase().contains(_searchQuery))
                .toList();
          }

          if (actions.isEmpty) {
            return RefreshIndicator(
              onRefresh: _refreshData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: SizedBox(
                  height: MediaQuery.of(context).size.height * 0.6,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(IconlyLight.folder,
                            size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          'No actions found',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _refreshData,
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: actions.length,
              itemBuilder: (context, index) {
                final action = actions[index];
                return _buildActionCard(action);
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _runMigration,
        icon: const Icon(IconlyLight.discovery),
        label: const Text('Process Completed Battles'),
        backgroundColor: AppColors.accent,
      ),
    );
  }

  Future<void> _runMigration() async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Process Completed Battles'),
        content: const Text(
          'This will check all active game sessions and mark any completed battles '
          'for results calculation. This is a one-time migration for existing battles.\n\n'
          'Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Run Migration'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Text('Processing...'),
            ],
          ),
        ),
      );

      // Call Cloud Function
      final functions = FirebaseFunctionsConfig.instance;
      final callable = functions.httpsCallable('migrateCompletedBattles');
      final result = await callable.call();

      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog

      // Show result
      final data = result.data as Map<String, dynamic>;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Migration Complete'),
          content: Text(
            '${data['message']}\n\n'
            'Completed battles: ${data['completedCount']}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Error'),
          content: Text('Migration failed: $e'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildFilterChip(String value, String label) {
    final isSelected = _selectedFilter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          setState(() => _selectedFilter = value);
        },
        backgroundColor: Colors.white,
        selectedColor: AppColors.primary.withOpacity(0.2),
        checkmarkColor: AppColors.primary,
      ),
    );
  }

  Widget _buildActionCard(AdminAction action) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: _getActionIcon(action.actionType),
          title: Text(
            action.actionDescription,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Text(
                DateFormat('MMM dd, yyyy - hh:mm a').format(action.timestamp),
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDetailRow('Action Type', action.actionType),
                  _buildDetailRow(
                    'Performed By',
                    _getUserName(action.performedBy),
                  ),
                  if (action.confirmedBy != null)
                    _buildDetailRow(
                      'Confirmed By',
                      _getUserName(action.confirmedBy!),
                    ),
                  if (action.sessionId != null)
                    _buildDetailRow('Session ID', action.sessionId!),
                  _buildDetailRow('Timestamp', action.timestamp.toString()),
                  if (action.details.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Text(
                      'Details:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...action.details.entries.map((entry) =>
                        _buildDetailRow(entry.key, entry.value.toString())),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getUserName(String userId) {
    // If users are still loading, show loading indicator
    if (_isLoadingUsers) {
      return 'Loading...';
    }
    // Look up user name from map, fallback to user ID if not found
    return _userIdToNameMap[userId] ?? 'Unknown User ($userId)';
  }

  Widget _getActionIcon(String actionType) {
    IconData icon;
    Color color;

    switch (actionType) {
      case AdminActionTypes.createGame:
        icon = IconlyLight.plus;
        color = AppColors.success;
        break;
      case AdminActionTypes.deleteGame:
        icon = IconlyLight.delete;
        color = AppColors.error;
        break;
      case AdminActionTypes.startBattle:
        icon = IconlyLight.play;
        color = AppColors.primary;
        break;
      case AdminActionTypes.endGame:
        icon = IconlyLight.close_square;
        color = AppColors.warning;
        break;
      case AdminActionTypes.sendReminder:
        icon = IconlyLight.notification;
        color = AppColors.accent;
        break;
      case AdminActionTypes.modifyDeadline:
        icon = IconlyLight.calendar;
        color = Colors.purple;
        break;
      case AdminActionTypes.resetDatabase:
        icon = IconlyLight.swap;
        color = AppColors.error;
        break;
      default:
        icon = IconlyLight.info_circle;
        color = AppColors.textSecondary;
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: color),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

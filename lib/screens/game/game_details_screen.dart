import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconly/iconly.dart';
import 'package:intl/intl.dart';

import '../../core/constants.dart';
import '../../core/firebase_functions_config.dart';
import '../../models/admin_action_model.dart';
import '../../models/game_session_model.dart';
import '../../models/user_model.dart';
import '../../providers/providers.dart';
import '../../utils/snackbar_helper.dart';
import '../../widgets/loading/async_loader.dart';

class GameDetailsScreen extends ConsumerStatefulWidget {
  final GameSession session;

  const GameDetailsScreen({super.key, required this.session});

  @override
  ConsumerState<GameDetailsScreen> createState() => _GameDetailsScreenState();
}

class _GameDetailsScreenState extends ConsumerState<GameDetailsScreen> {
  bool _isLoading = false;
  late GameSession _currentSession;

  @override
  void initState() {
    super.initState();
    _currentSession = widget.session;
  }

  Future<void> _refreshSessionData() async {
    setState(() => _isLoading = true);
    try {
      // Fetch the latest session data from Firestore
      final sessionDoc = await FirebaseFirestore.instance
          .collection('gameSessions')
          .doc(_currentSession.id)
          .get();

      if (mounted && sessionDoc.exists) {
        final updatedSession = GameSession.fromFirestore(sessionDoc);
        setState(() {
          _currentSession = updatedSession;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showError('Failed to refresh session data: $e');
      }
    }
  }

  Future<void> _startBattleManually() async {
    if (!_currentSession.bothPlayersSubmitted) {
      _showError('Both players must submit questions before starting battle');
      return;
    }

    final confirm = await _showConfirmDialog(
      'Start Battle',
      'Are you sure you want to start the battle now?',
    );
    if (!confirm) return;

    final result = await AsyncLoader.execute(
      context: context,
      message: 'Starting battle...',
      asyncTask: () async {
        await ref.read(firestoreServiceProvider).updateGameSession(
          _currentSession.id,
          {'status': GameStatus.active},
        );

        final currentUserId = ref.read(currentUserIdProvider) ?? 'unknown';
        await ref.read(firestoreServiceProvider).logAdminAction(
              AdminAction(
                id: '',
                performedBy: currentUserId,
                actionType: AdminActionTypes.startBattle,
                timestamp: DateTime.now(),
                sessionId: _currentSession.id,
                details: {'reason': 'Manual start'},
              ),
            );

        return true;
      },
    );

    if (!mounted) return;

    result.fold(
      (error) => _showError('Failed to start battle: $error'),
      (_) async {
        _showSuccess('Battle started successfully!');
        await _refreshSessionData();
      },
    );
  }

  Future<void> _endGame() async {
    final confirm = await _showConfirmDialog(
      'End Game',
      'Are you sure you want to end this game? This action cannot be undone.',
    );
    if (!confirm) return;

    final result = await AsyncLoader.execute(
      context: context,
      message: 'Ending game...',
      asyncTask: () async {
        await ref.read(firestoreServiceProvider).updateGameSession(
          _currentSession.id,
          {'status': GameStatus.completed},
        );

        final currentUserId = ref.read(currentUserIdProvider) ?? 'unknown';
        await ref.read(firestoreServiceProvider).logAdminAction(
              AdminAction(
                id: '',
                performedBy: currentUserId,
                actionType: AdminActionTypes.endGame,
                timestamp: DateTime.now(),
                sessionId: _currentSession.id,
                details: {'reason': 'Manual end'},
              ),
            );

        return true;
      },
    );

    if (!mounted) return;

    result.fold(
      (error) => _showError('Failed to end game: $error'),
      (_) {
        _showSuccess('Game ended successfully!');
        Navigator.of(context).pop();
      },
    );
  }

  Future<void> _deleteGame() async {
    // Show input dialog for deletion reason
    String? reason;
    final reasonController = TextEditingController();

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Game'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Are you sure you want to delete this game? This will:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text('• Remove all game data'),
            const Text('• Delete all questions and answers'),
            const Text('• Update player statistics'),
            const Text('• Notify both players'),
            const Text('• Archive to game history'),
            const SizedBox(height: 16),
            const Text(
              'This action cannot be undone.',
              style: TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason (optional)',
                hintText: 'Why are you deleting this game?',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              reason = reasonController.text.trim();
              Navigator.of(context).pop(true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (shouldDelete != true) return;

    final result = await AsyncLoader.execute(
      context: context,
      message: 'Deleting game...',
      asyncTask: () async {
        await ref.read(firestoreServiceProvider).deleteGame(
              sessionId: _currentSession.id,
              reason: reason?.isEmpty ?? true ? null : reason,
            );
        return true;
      },
    );

    if (!mounted) return;

    result.fold(
      (error) => _showError('Failed to delete game: $error'),
      (_) {
        _showSuccess('Game deleted successfully!');
        Navigator.of(context).pop();
      },
    );
  }

  Future<void> _sendReminder(String playerId, String playerName) async {
    final confirm = await _showConfirmDialog(
      'Send Reminder',
      'Send a push notification reminder to $playerName?',
    );
    if (!confirm) return;

    final result = await AsyncLoader.execute(
      context: context,
      message: 'Sending reminder...',
      asyncTask: () async {
        // Call Cloud Function to send push notification
        final functions = FirebaseFunctionsConfig.instance;
        await functions.httpsCallable('sendNotification').call({
          'userId': playerId,
          'title': 'Reminder: Submit Your Questions',
          'body':
              'Don\'t forget to submit your questions before the deadline (${DateFormat('MMM dd, hh:mm a').format(_currentSession.submissionDeadline)})!',
          'data': {
            'type': 'deadlineReminder',
            'sessionId': _currentSession.id,
            'deadline': _currentSession.submissionDeadline.toIso8601String(),
          },
        });

        // Log admin action
        final currentUserId = ref.read(currentUserIdProvider) ?? 'unknown';
        await ref.read(firestoreServiceProvider).logAdminAction(
              AdminAction(
                id: '',
                performedBy: currentUserId,
                actionType: AdminActionTypes.sendReminder,
                timestamp: DateTime.now(),
                sessionId: _currentSession.id,
                details: {'playerId': playerId, 'playerName': playerName},
              ),
            );

        return true;
      },
    );

    if (!mounted) return;

    result.fold(
      (error) => _showError('Failed to send reminder: $error'),
      (_) => _showSuccess('Reminder sent to $playerName!'),
    );
  }

  Future<void> _modifyDeadline() async {
    DateTime? tempDate = _currentSession.submissionDeadline;

    await showCupertinoModalPopup(
      context: context,
      builder: (context) => Container(
        height: 300,
        color: CupertinoColors.systemBackground.resolveFrom(context),
        child: Column(
          children: [
            // Done button
            Container(
              height: 50,
              decoration: BoxDecoration(
                color: CupertinoColors.systemBackground.resolveFrom(context),
                border: const Border(
                  bottom: BorderSide(
                    color: CupertinoColors.separator,
                    width: 0.5,
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CupertinoButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  CupertinoButton(
                    onPressed: () async {
                      Navigator.of(context).pop();
                      // Save the new deadline
                      final newDeadline = tempDate;

                      // Check if deadline actually changed
                      if (newDeadline?.isAtSameMomentAs(
                              _currentSession.submissionDeadline) ??
                          false) {
                        if (mounted) {
                          SnackBarHelper.showInfoSnackBar(
                            context,
                            'No changes made to deadline',
                          );
                        }
                        return;
                      }

                      final result = await AsyncLoader.execute(
                        context: context,
                        message: 'Updating deadline...',
                        asyncTask: () async {
                          await ref
                              .read(firestoreServiceProvider)
                              .updateGameSession(
                            _currentSession.id,
                            {'submissionDeadline': newDeadline},
                          );

                          final currentUserId =
                              ref.read(currentUserIdProvider) ?? 'unknown';
                          await ref
                              .read(firestoreServiceProvider)
                              .logAdminAction(
                                AdminAction(
                                  id: '',
                                  performedBy: currentUserId,
                                  actionType: AdminActionTypes.modifyDeadline,
                                  timestamp: DateTime.now(),
                                  sessionId: _currentSession.id,
                                  details: {
                                    'oldDeadline': _currentSession
                                        .submissionDeadline
                                        .toString(),
                                    'newDeadline': newDeadline.toString(),
                                  },
                                ),
                              );

                          return true;
                        },
                      );

                      if (!mounted) return;

                      result.fold(
                        (error) =>
                            _showError('Failed to update deadline: $error'),
                        (_) async {
                          _showSuccess('Deadline updated successfully!');
                          await _refreshSessionData();
                        },
                      );
                    },
                    child: const Text('Done'),
                  ),
                ],
              ),
            ),
            // Date picker
            Expanded(
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.dateAndTime,
                initialDateTime: tempDate,
                minimumDate: DateTime.now(),
                maximumDate: DateTime.now().add(const Duration(days: 365)),
                onDateTimeChanged: (DateTime value) {
                  tempDate = value;
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _showConfirmDialog(String title, String message) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _showError(String message) {
    SnackBarHelper.showErrorSnackBar(context, message);
  }

  void _showSuccess(String message) {
    SnackBarHelper.showSuccessSnackBar(context, message);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Game Details'),
        actions: [
          IconButton(
            icon: const Icon(CupertinoIcons.refresh),
            onPressed: _refreshSessionData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _refreshSessionData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStatusCard(),
                    const SizedBox(height: 16),
                    _buildTimelineCard(),
                    const SizedBox(height: 16),
                    _buildPlayerCard(
                      _currentSession.player1Id,
                      'Player 1',
                      _currentSession.player1Progress,
                    ),
                    const SizedBox(height: 16),
                    _buildPlayerCard(
                      _currentSession.player2Id,
                      'Player 2',
                      _currentSession.player2Progress,
                    ),
                    const SizedBox(height: 16),
                    _buildActionsCard(),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildStatusCard() {
    Color statusColor;
    IconData statusIcon;
    String statusText;

    switch (_currentSession.status) {
      case GameStatus.preparation:
        statusColor = AppColors.warning;
        statusIcon = IconlyLight.edit;
        statusText = 'Preparation Phase';
        break;
      case GameStatus.ready:
        statusColor = AppColors.info;
        statusIcon = CupertinoIcons.checkmark_circle;
        statusText = 'Ready to Start';
        break;
      case GameStatus.active:
        statusColor = AppColors.success;
        statusIcon = IconlyLight.play;
        statusText = 'Battle Active';
        break;
      case GameStatus.completed:
        statusColor = AppColors.textSecondary;
        statusIcon = CupertinoIcons.checkmark_circle;
        statusText = 'Completed';
        break;
      default:
        statusColor = AppColors.textSecondary;
        statusIcon = IconlyLight.info_circle;
        statusText = 'Unknown';
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(statusIcon, color: statusColor, size: 32),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    statusText,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Session ID: ${_currentSession.id}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Timeline',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildTimelineItem(
              IconlyLight.plus,
              'Game Created',
              DateFormat('MMM dd, yyyy - hh:mm a')
                  .format(_currentSession.createdAt),
              AppColors.success,
            ),
            _buildTimelineItem(
              IconlyLight.calendar,
              'Submission Deadline',
              DateFormat('MMM dd, yyyy - hh:mm a')
                  .format(_currentSession.submissionDeadline),
              AppColors.warning,
            ),
            _buildTimelineItem(
              IconlyLight.game,
              'Battle Date',
              DateFormat('MMM dd, yyyy - hh:mm a')
                  .format(_currentSession.battleDate),
              AppColors.primary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineItem(
      IconData icon, String label, String time, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
                Text(
                  time,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerCard(
      String playerId, String playerLabel, PlayerProgress progress) {
    return FutureBuilder<UserModel>(
      future: ref.read(firestoreServiceProvider).getAllUsers().then(
            (users) => users.firstWhere((u) => u.uid == playerId),
          ),
      builder: (context, snapshot) {
        final userName =
            snapshot.hasData ? snapshot.data!.displayName : 'Loading...';
        final userEmail = snapshot.hasData ? snapshot.data!.email : '';
        final photoURL = snapshot.hasData ? snapshot.data!.photoURL : null;

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundImage:
                          photoURL != null ? NetworkImage(photoURL) : null,
                      child: photoURL == null
                          ? const Icon(IconlyLight.profile)
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            userName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            userEmail,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 8),
                    if (!progress.hasSubmitted &&
                        _currentSession.status == GameStatus.preparation &&
                        playerId != ref.read(currentUserIdProvider))
                      ElevatedButton.icon(
                        onPressed: () => _sendReminder(playerId, userName),
                        icon: const Icon(IconlyLight.notification, size: 18),
                        label: const Text('Remind'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accent,
                        ),
                      ),
                  ],
                ),
                const Divider(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: _buildProgressStat(
                        'Questions',
                        '${progress.questionsCreated}/${_currentSession.totalQuestionsRequired}',
                        progress.questionsCreated == _currentSession.totalQuestionsRequired
                            ? AppColors.success
                            : AppColors.textSecondary,
                      ),
                    ),
                    Expanded(
                      child: _buildProgressStat(
                        'Answered',
                        '${progress.questionsAnswered}/${_currentSession.totalQuestionsRequired}',
                        AppColors.primary,
                      ),
                    ),
                    Expanded(
                      child: _buildProgressStat(
                        'Accuracy',
                        '${progress.accuracy.toStringAsFixed(0)}%',
                        AppColors.info,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (progress.selectedLetters.isNotEmpty) ...[
                  const Text(
                    'Selected Letters:',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: progress.selectedLetters
                        .map((letter) => Container(
                              margin: const EdgeInsets.only(right: 8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: AppColors.primary.withOpacity(0.3),
                                ),
                              ),
                              child: Text(
                                letter,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              ),
                            ))
                        .toList(),
                  ),
                ],
                if (progress.hasSubmitted) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(CupertinoIcons.checkmark_circle,
                          color: AppColors.success, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        'Submitted ${DateFormat('MMM dd, hh:mm a').format(progress.submittedAt!)}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.success,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildProgressStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildActionsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Admin Actions',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_currentSession.status == GameStatus.preparation)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _modifyDeadline,
                      icon: const Icon(IconlyLight.calendar),
                      label: const Text('Modify Deadline'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple,
                      ),
                    ),
                  ),
                if (_currentSession.status == GameStatus.preparation)
                  const SizedBox(height: 8),
                if (_currentSession.status == GameStatus.ready ||
                    (_currentSession.status == GameStatus.preparation &&
                        _currentSession.bothPlayersSubmitted))
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _startBattleManually,
                      icon: const Icon(IconlyLight.play),
                      label: const Text('Start Battle'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                      ),
                    ),
                  ),
                if (_currentSession.status == GameStatus.ready ||
                    (_currentSession.status == GameStatus.preparation &&
                        _currentSession.bothPlayersSubmitted))
                  const SizedBox(height: 8),
                if (_currentSession.status != GameStatus.completed)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _endGame,
                      icon: const Icon(IconlyLight.close_square),
                      label: const Text('End Game'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.error,
                      ),
                    ),
                  ),
                if (_currentSession.status != GameStatus.completed)
                  const SizedBox(height: 8),
                // Delete Game button - available for all statuses
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _deleteGame,
                    icon: const Icon(IconlyLight.delete),
                    label: const Text('Delete Game'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade700,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

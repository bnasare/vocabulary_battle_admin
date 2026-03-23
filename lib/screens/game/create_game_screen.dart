import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconly/iconly.dart';
import 'package:intl/intl.dart';

import '../../core/constants.dart';
import '../../models/admin_action_model.dart';
import '../../models/game_mode.dart';
import '../../models/user_model.dart';
import '../../providers/providers.dart';
import '../../utils/snackbar_helper.dart';
import '../../widgets/loading/async_loader.dart';
import '../../widgets/opponent_selector.dart';

class CreateGameScreen extends ConsumerStatefulWidget {
  const CreateGameScreen({super.key});

  @override
  ConsumerState<CreateGameScreen> createState() => _CreateGameScreenState();
}

class _CreateGameScreenState extends ConsumerState<CreateGameScreen> {
  DateTime? _submissionDeadline;
  DateTime? _battleDate;
  String? _opponentId;
  List<UserModel>? _availableOpponents;
  GameMode _selectedMode = GameMode.defaultMode;

  @override
  void initState() {
    super.initState();
    // Set default dates based on default game mode
    _updateDatesForGameMode(_selectedMode);
    // Load opponents after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadOpponents();
    });
  }

  void _updateDatesForGameMode(GameMode mode) {
    final now = DateTime.now();
    // Set submission deadline and battle date based on game mode
    switch (mode) {
      case GameMode.quick:
        // Quick: 1 day to submit, battle in 2 days
        _submissionDeadline = now.add(const Duration(days: 1));
        _battleDate = now.add(const Duration(days: 2));
        break;
      case GameMode.normal:
        // Normal: 2 days to submit, battle in 3 days
        _submissionDeadline = now.add(const Duration(days: 2));
        _battleDate = now.add(const Duration(days: 3));
        break;
      case GameMode.challenge:
        // Challenge: 3 days to submit, battle in 5 days
        _submissionDeadline = now.add(const Duration(days: 3));
        _battleDate = now.add(const Duration(days: 5));
        break;
    }
  }

  Future<void> _loadOpponents() async {
    final result = await AsyncLoader.execute(
      context: context,
      message: 'Fetching available opponents...',
      asyncTask: () async {
        final firestoreService = ref.read(firestoreServiceProvider);
        final users = await firestoreService.getAllUsers();
        final usersInGames = await firestoreService.getUsersWithActiveGames();
        final currentUserId = ref.read(currentUserIdProvider);

        // Filter out current user and users already in active games
        return users
            .where((user) =>
                user.uid != currentUserId && !usersInGames.contains(user.uid))
            .toList();
      },
    );

    if (!mounted) return;

    result.fold(
      (error) {
        SnackBarHelper.showErrorSnackBar(
          context,
          'Error loading opponents: $error',
        );
      },
      (opponents) {
        setState(() {
          _availableOpponents = opponents;
        });
      },
    );
  }

  Future<void> _selectSubmissionDeadline() async {
    DateTime? tempDate = _submissionDeadline ?? DateTime.now();

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
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  CupertinoButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      if (mounted) {
                        setState(() {
                          _submissionDeadline = tempDate;
                        });
                      }
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

  Future<void> _selectBattleDate() async {
    DateTime? tempDate = _battleDate ?? DateTime.now();

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
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  CupertinoButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      if (mounted) {
                        setState(() {
                          _battleDate = tempDate;
                        });
                      }
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
                minimumDate: _submissionDeadline ?? DateTime.now(),
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

  void _showOpponentInfoDialog() {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Available Opponents'),
        content: const Text(
          'Only users who are not currently in an active game are shown here.\n\n'
          'Users with games in preparation, ready, or active status are automatically '
          'filtered out to ensure each player can focus on one game at a time.',
        ),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  Future<void> _createGame() async {
    if (_submissionDeadline == null || _battleDate == null) {
      SnackBarHelper.showWarningSnackBar(
        context,
        'Please set both dates',
      );
      return;
    }

    if (_battleDate!.isBefore(_submissionDeadline!)) {
      SnackBarHelper.showWarningSnackBar(
        context,
        'Battle date must be after submission deadline',
      );
      return;
    }

    if (_opponentId == null) {
      SnackBarHelper.showWarningSnackBar(
        context,
        'Please select an opponent',
      );
      return;
    }

    final result = await AsyncLoader.execute(
      context: context,
      message: 'Creating game...',
      asyncTask: () async {
        final currentUserId = ref.read(currentUserIdProvider);
        if (currentUserId == null) throw Exception('Not logged in');

        // Get selected opponent
        final firestoreService = ref.read(firestoreServiceProvider);
        final users = await firestoreService.getAllUsers();

        // Find selected opponent
        final opponent = users.firstWhere(
          (u) => u.uid == _opponentId,
          orElse: () => throw Exception('Selected opponent not found'),
        );

        // Create game session
        final sessionId = await firestoreService.createGameSession(
          player1Id: currentUserId,
          player2Id: opponent.uid,
          submissionDeadline: _submissionDeadline!,
          battleDate: _battleDate!,
          gameMode: _selectedMode,
        );

        // Log admin action
        await firestoreService.logAdminAction(
          AdminAction(
            id: '',
            performedBy: currentUserId,
            actionType: AdminActionTypes.createGame,
            sessionId: sessionId,
            details: {
              'submissionDeadline': _submissionDeadline!.toIso8601String(),
              'battleDate': _battleDate!.toIso8601String(),
              'opponent': opponent.displayName,
              'gameMode': _selectedMode.value,
            },
            timestamp: DateTime.now(),
          ),
        );

        return sessionId;
      },
    );

    if (!mounted) return;

    result.fold(
      (error) {
        SnackBarHelper.showErrorSnackBar(
          context,
          'Error creating game: $error',
        );
      },
      (sessionId) {
        SnackBarHelper.showSuccessSnackBar(
          context,
          'Game created successfully!',
        );
        Navigator.of(context).pop();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Create button
      bottomNavigationBar: SafeArea(
        child: Container(
          margin: const EdgeInsets.all(16),
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _createGame,
            child: const Text('Create Game'),
          ),
        ),
      ),
      appBar: AppBar(
        title: const Text('Create New Game'),
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 8,
              ),
              const Text(
                'Timeline',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 24),

              // Submission Deadline
              Card(
                child: ListTile(
                  leading: const Icon(IconlyLight.time_circle,
                      color: AppColors.primary),
                  title: const Text('Submission Deadline'),
                  subtitle: Text(
                    _submissionDeadline != null
                        ? DateFormat('MMM dd, yyyy - hh:mm a')
                            .format(_submissionDeadline!)
                        : 'Not set',
                  ),
                  trailing: const Icon(IconlyLight.edit),
                  onTap: _selectSubmissionDeadline,
                ),
              ),
              const SizedBox(height: 12),

              // Battle Date
              Card(
                child: ListTile(
                  leading: const Icon(IconlyLight.calendar,
                      color: AppColors.primary),
                  title: const Text('Battle Date'),
                  subtitle: Text(
                    _battleDate != null
                        ? DateFormat('MMM dd, yyyy - hh:mm a')
                            .format(_battleDate!)
                        : 'Not set',
                  ),
                  trailing: const Icon(IconlyLight.edit),
                  onTap: _selectBattleDate,
                ),
              ),
              const SizedBox(height: 32),

              // Game Mode Selection
              const Text(
                'Game Mode',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              ...GameMode.values.map((mode) => _buildGameModeCard(mode)).toList(),
              const SizedBox(height: 32),

              // Opponent Selection
              if (_availableOpponents == null)
                SizedBox(
                  width: double.infinity,
                  child: const Card(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child:
                          Center(child: Text('Fetching available opponents...')),
                    ),
                  ),
                )
              else if (_availableOpponents!.isEmpty)
                SizedBox(
                  width: double.infinity,
                  child: const Card(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Center(child: Text('No opponents available')),
                    ),
                  ),
                )
              else
                OpponentSelector(
                  title: 'Battle Against',
                  hintText: 'Search by name or email...',
                  opponents: _availableOpponents!,
                  selectedOpponentId: _opponentId,
                  onSelectionChanged: (opponentId) {
                    setState(() => _opponentId = opponentId);
                  },
                  onInfoTap: _showOpponentInfoDialog,
                ),
              const SizedBox(height: 32),

              // Info card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.primary.withOpacity(0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.info_outline,
                          color: AppColors.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Game Flow',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildInfoItem('1. Players create ${_selectedMode.totalQuestions} questions each'),
                    _buildInfoItem('2. Submit before the deadline'),
                    _buildInfoItem('3. Battle starts on scheduled date'),
                    _buildInfoItem('4. Players answer opponent\'s questions'),
                    _buildInfoItem('5. View results and statistics'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGameModeCard(GameMode mode) {
    final isSelected = _selectedMode == mode;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedMode = mode;
          // Update dates when mode changes
          _updateDatesForGameMode(mode);
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withOpacity(0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : AppColors.textSecondary.withOpacity(0.2),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: Icon(
            isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
            color: isSelected ? AppColors.primary : AppColors.textSecondary,
          ),
          title: Text(
            mode.displayName,
            style: TextStyle(
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              color: isSelected ? AppColors.primary : AppColors.textPrimary,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              mode.description,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline,
              size: 16, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

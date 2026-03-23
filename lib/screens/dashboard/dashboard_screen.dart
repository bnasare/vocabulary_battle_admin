import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconly/iconly.dart';
import 'package:intl/intl.dart';

import '../../core/constants.dart';
import '../../models/game_session_model.dart';
import '../../models/user_model.dart';
import '../../providers/providers.dart';
import '../admin_actions/admin_actions_screen.dart';
import '../game/create_game_screen.dart';
import '../game/game_details_screen.dart';
import '../history/history_screen.dart';
import '../statistics/statistics_screen.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(currentUserProvider);
    final activeGameSession = ref.watch(activeGameSessionProvider);

    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        title: const Text('Admin Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(IconlyLight.time_circle),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const HistoryScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(IconlyLight.document),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const AdminActionsScreen(),
                ),
              );
            },
          ),
          PopupMenuButton(
            icon: const Icon(IconlyLight.more_circle),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(IconlyLight.logout, size: 20, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Logout', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
            onSelected: (value) {
              if (value == 'logout') {
                // Schedule the sign out after the current frame completes
                // and popup menu animation finishes
                Future.delayed(const Duration(milliseconds: 300), () async {
                  try {
                    // Clear cached images to prevent showing old user's photo
                    PaintingBinding.instance.imageCache.clear();
                    PaintingBinding.instance.imageCache.clearLiveImages();

                    // Invalidate all providers to clear cached user data
                    // This must happen BEFORE signOut to ensure clean state
                    ref.invalidate(currentUserProvider);
                    ref.invalidate(activeGameSessionProvider);
                    ref.invalidate(gameHistoryProvider);
                    ref.invalidate(statisticsProvider);
                    ref.invalidate(authStateProvider);
                    ref.invalidate(loadingProvider);
                    ref.invalidate(errorMessageProvider);
                    ref.invalidate(successMessageProvider);

                    // Sign out from Firebase and Google
                    final authService = ref.read(authServiceProvider);
                    await authService.signOut();
                  } catch (e) {
                    // Silently handle errors as context may not be available
                  }
                });
              }
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(activeGameSessionProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // User welcome card
              currentUser.when(
                data: (user) {
                  if (user == null) return const SizedBox.shrink();
                  return _buildWelcomeCard(user.displayName, user.photoURL);
                },
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),
              const SizedBox(height: 24),

              // Active game status
              activeGameSession.when(
                data: (session) {
                  if (session == null) {
                    return _buildNoActiveGameCard(context);
                  }
                  return _buildActiveGameCard(context, session, ref);
                },
                loading: () => const Center(
                  child: CircularProgressIndicator(),
                ),
                error: (error, stack) => Center(
                  child: Text('Error loading game: $error'),
                ),
              ),
              const SizedBox(height: 24),

              // Quick actions
              _buildQuickActionsSection(context, activeGameSession),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeCard(String displayName, String? photoURL) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                shape: BoxShape.circle,
                image: photoURL != null
                    ? DecorationImage(
                        image: NetworkImage(photoURL),
                        fit: BoxFit.cover,
                        onError: (exception, stackTrace) {
                          // If image fails to load, it will show the icon below
                        },
                      )
                    : null,
              ),
              child: photoURL == null
                  ? const Icon(
                      IconlyLight.profile,
                      color: AppColors.primary,
                      size: 30,
                    )
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Welcome back,',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
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

  Widget _buildNoActiveGameCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                IconlyLight.game,
                color: AppColors.primary,
                size: 40,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'No Active Game',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Create a new game session to get started',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const CreateGameScreen(),
                    ),
                  );
                },
                icon: const Icon(IconlyLight.plus),
                label: const Text('Create New Game'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveGameCard(
      BuildContext context, GameSession session, WidgetRef ref) {
    final now = DateTime.now();
    final isBeforeDeadline = now.isBefore(session.submissionDeadline);
    final isBeforeBattle = now.isBefore(session.battleDate);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Active Game',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                _buildStatusChip(session.status),
              ],
            ),
            const Divider(height: 32),

            // Submission deadline
            _buildInfoRow(
              IconlyLight.time_circle,
              'Submission Deadline',
              DateFormat('MMM dd, yyyy - hh:mm a')
                  .format(session.submissionDeadline),
              isOverdue: !isBeforeDeadline,
            ),
            const SizedBox(height: 12),

            // Battle date
            _buildInfoRow(
              IconlyLight.calendar,
              'Battle Date',
              DateFormat('MMM dd, yyyy - hh:mm a').format(session.battleDate),
            ),
            const Divider(height: 24),

            // Players progress
            FutureBuilder<List<UserModel>>(
              future: ref.read(firestoreServiceProvider).getAllUsers().then(
                    (users) => [
                      users.firstWhere((u) => u.uid == session.player1Id),
                      users.firstWhere((u) => u.uid == session.player2Id),
                    ],
                  ),
              builder: (context, snapshot) {
                final player1Name = snapshot.hasData
                    ? snapshot.data![0].displayName.split(' ').first
                    : 'Player 1';
                final player2Name = snapshot.hasData
                    ? snapshot.data![1].displayName.split(' ').first
                    : 'Player 2';

                return Row(
                  children: [
                    Expanded(
                      child: _buildPlayerProgress(
                        player1Name,
                        session.player1Progress,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildPlayerProgress(
                        player2Name,
                        session.player2Progress,
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 20),

            // Action button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => GameDetailsScreen(session: session),
                    ),
                  );
                },
                child: const Text('View Game Details'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    String label;

    switch (status) {
      case GameStatus.preparation:
        color = AppColors.warning;
        label = 'Preparation';
        break;
      case GameStatus.ready:
        color = AppColors.success;
        label = 'Ready';
        break;
      case GameStatus.active:
        color = AppColors.primary;
        label = 'Active';
        break;
      case GameStatus.completed:
        color = AppColors.textSecondary;
        label = 'Completed';
        break;
      default:
        color = Colors.grey;
        label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value,
      {bool isOverdue = false}) {
    return Row(
      children: [
        Icon(icon,
            size: 20,
            color: isOverdue ? AppColors.error : AppColors.textSecondary),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: isOverdue ? AppColors.error : AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPlayerProgress(String label, PlayerProgress progress) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: progress.hasSubmitted
            ? AppColors.success.withOpacity(0.1)
            : AppColors.warning.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: progress.hasSubmitted
              ? AppColors.success.withOpacity(0.3)
              : AppColors.warning.withOpacity(0.3),
        ),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Icon(
            progress.hasSubmitted
                ? CupertinoIcons.checkmark_circle
                : IconlyLight.time_circle,
            color:
                progress.hasSubmitted ? AppColors.success : AppColors.warning,
            size: 24,
          ),
          const SizedBox(height: 4),
          Text(
            progress.hasSubmitted ? 'Submitted' : 'Pending',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color:
                  progress.hasSubmitted ? AppColors.success : AppColors.warning,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsSection(
      BuildContext context, AsyncValue<GameSession?> activeGameSession) {
    // Extract the session value from AsyncValue
    final session = activeGameSession.valueOrNull;
    final hasActiveGame = session != null;

    // Build list of quick actions conditionally
    final quickActions = <Widget>[
      // Only show Create Game if there's no active game
      if (!hasActiveGame)
        _buildQuickActionCard(
          icon: IconlyLight.plus,
          label: 'Create Game',
          color: AppColors.primary,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const CreateGameScreen(),
              ),
            );
          },
        ),
      _buildQuickActionCard(
        icon: IconlyLight.time_circle,
        label: 'History',
        color: AppColors.accent,
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const HistoryScreen(),
            ),
          );
        },
      ),
      _buildQuickActionCard(
        icon: IconlyLight.document,
        label: 'Admin Log',
        color: Colors.purple,
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const AdminActionsScreen(),
            ),
          );
        },
      ),
      _buildQuickActionCard(
        icon: IconlyLight.chart,
        label: 'Statistics',
        color: Colors.green,
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const StatisticsScreen(),
            ),
          );
        },
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Actions',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.5,
          children: quickActions,
        ),
      ],
    );
  }

  Widget _buildQuickActionCard({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 32),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

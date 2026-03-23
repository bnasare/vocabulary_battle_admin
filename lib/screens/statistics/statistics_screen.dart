import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconly/iconly.dart';

import '../../core/constants.dart';
import '../../models/user_model.dart';
import '../../providers/providers.dart';
import '../../services/statistics_service.dart';

class StatisticsScreen extends ConsumerWidget {
  const StatisticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statisticsAsync = ref.watch(statisticsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Platform Statistics'),
      ),
      body: statisticsAsync.when(
        data: (stats) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(statisticsProvider);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Overview Cards
                _buildOverviewCards(stats),
                const SizedBox(height: 24),

                // Win Rate Chart
                _buildWinRateChart(stats),
                const SizedBox(height: 24),

                // Top Players
                _buildTopPlayersSection(stats),
                const SizedBox(height: 24),

                // Games by Status
                _buildGamesByStatusChart(stats),
                const SizedBox(height: 24),

                // Achievements
                _buildAchievementsSection(stats),
                const SizedBox(height: 24),

                // Recent Games
                _buildRecentGamesSection(stats),
              ],
            ),
          ),
        ),
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(IconlyLight.danger, size: 48, color: AppColors.error),
              const SizedBox(height: 16),
              Text('Error loading statistics: $error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.invalidate(statisticsProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOverviewCards(PlatformStatistics stats) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: [
        _buildStatCard(
          icon: IconlyLight.user,
          label: 'Total Users',
          value: stats.totalUsers.toString(),
          color: AppColors.primary,
        ),
        _buildStatCard(
          icon: IconlyLight.game,
          label: 'Total Games',
          value: stats.totalGames.toString(),
          color: AppColors.accent,
        ),
        _buildStatCard(
          icon: IconlyLight.activity,
          label: 'Active Games',
          value: stats.activeGames.toString(),
          color: Colors.orange,
        ),
        _buildStatCard(
          icon: CupertinoIcons.checkmark_circle,
          label: 'Completed',
          value: stats.completedGames.toString(),
          color: AppColors.success,
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWinRateChart(PlatformStatistics stats) {
    final totalWins =
        stats.topPlayers.fold<int>(0, (sum, user) => sum + user.stats.wins);
    final totalLosses =
        stats.topPlayers.fold<int>(0, (sum, user) => sum + user.stats.losses);

    if (totalWins == 0 && totalLosses == 0) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Overall Win/Loss Distribution',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 30),
            SizedBox(
              height: 200,
              child: PieChart(
                PieChartData(
                  sections: [
                    PieChartSectionData(
                      value: totalWins.toDouble(),
                      title: '$totalWins\nWins',
                      color: AppColors.success,
                      radius: 80,
                      titleStyle: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    PieChartSectionData(
                      value: totalLosses.toDouble(),
                      title: '$totalLosses\nLosses',
                      color: AppColors.error,
                      radius: 80,
                      titleStyle: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                  sectionsSpace: 2,
                  centerSpaceRadius: 40,
                ),
              ),
            ),
            const SizedBox(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Win Rate: ${stats.overallWinRate.toStringAsFixed(1)}%',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  'Avg Accuracy: ${stats.averageAccuracy.toStringAsFixed(1)}%',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopPlayersSection(PlatformStatistics stats) {
    if (stats.topPlayers.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Top Players',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        ...stats.topPlayers.asMap().entries.map((entry) {
          final index = entry.key;
          final user = entry.value;
          return _buildPlayerCard(user, index + 1);
        }),
      ],
    );
  }

  Widget _buildPlayerCard(UserModel user, int rank) {
    final winRate = user.stats.gamesPlayed > 0
        ? (user.stats.wins / user.stats.gamesPlayed * 100)
        : 0.0;

    Color rankColor;
    IconData rankIcon;
    switch (rank) {
      case 1:
        rankColor = Colors.amber;
        rankIcon = IconlyLight.star;
        break;
      case 2:
        rankColor = Colors.grey[400]!;
        rankIcon = IconlyLight.star;
        break;
      case 3:
        rankColor = Colors.brown[300]!;
        rankIcon = IconlyLight.star;
        break;
      default:
        rankColor = AppColors.textSecondary;
        rankIcon = IconlyLight.star;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: rankColor.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Icon(rankIcon, color: rankColor, size: 24),
          ),
        ),
        title: Text(
          user.displayName,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          '${user.stats.wins} wins • ${winRate.toStringAsFixed(0)}% win rate',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${user.stats.gamesPlayed}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
            const Text(
              'games',
              style: TextStyle(
                fontSize: 10,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGamesByStatusChart(PlatformStatistics stats) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Games by Status',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: stats.gamesByStatus.values
                          .reduce((a, b) => a > b ? a : b)
                          .toDouble() *
                      1.2,
                  barGroups: [
                    _buildBarGroup(0, stats.gamesByStatus['preparation'] ?? 0,
                        AppColors.warning),
                    _buildBarGroup(1, stats.gamesByStatus['ready'] ?? 0,
                        AppColors.success),
                    _buildBarGroup(2, stats.gamesByStatus['active'] ?? 0,
                        AppColors.primary),
                    _buildBarGroup(3, stats.gamesByStatus['completed'] ?? 0,
                        AppColors.textSecondary),
                  ],
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          const titles = ['Prep', 'Ready', 'Active', 'Done'];
                          return Text(
                            titles[value.toInt()],
                            style: const TextStyle(fontSize: 12),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            value.toInt().toString(),
                            style: const TextStyle(fontSize: 12),
                          );
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  BarChartGroupData _buildBarGroup(int x, int value, Color color) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: value.toDouble(),
          color: color,
          width: 20,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
        ),
      ],
    );
  }

  Widget _buildAchievementsSection(PlatformStatistics stats) {
    if (stats.achievementCounts.isEmpty) {
      return const SizedBox.shrink();
    }

    final achievementNames = {
      'hot_streak': '🔥 Hot Streak',
      'champion': '🏆 Champion',
      'flawless': '💯 Flawless',
      'sniper': '🎯 Sniper',
      'perfectionist': '📚 Perfectionist',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Achievement Distribution',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: stats.achievementCounts.entries.map((entry) {
                final name = achievementNames[entry.key] ?? entry.key;
                final count = entry.value;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          count.toString(),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRecentGamesSection(PlatformStatistics stats) {
    if (stats.recentGames.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Recent Completed Games',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        ...stats.recentGames.map((game) {
          final player1Score = game.result?.player1FinalScore ?? 0;
          final player2Score = game.result?.player2FinalScore ?? 0;
          final timeAgo = _getTimeAgo(game.createdAt);

          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: Icon(
                IconlyLight.star,
                color: player1Score > player2Score
                    ? AppColors.success
                    : AppColors.error,
              ),
              title: Text(
                'Game ${game.id.substring(0, 8)}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                'Score: $player1Score - $player2Score',
                style: const TextStyle(fontSize: 12),
              ),
              trailing: Text(
                timeAgo,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}

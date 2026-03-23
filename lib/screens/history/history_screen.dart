import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconly/iconly.dart';
import 'package:intl/intl.dart';
import '../../providers/providers.dart';
import '../../core/constants.dart';
import '../../models/game_session_model.dart';
import '../results/admin_results_screen.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  String _selectedFilter = 'all';

  @override
  Widget build(BuildContext context) {
    final currentUserId = ref.watch(currentUserIdProvider);

    if (currentUserId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Game History')),
        body: const Center(child: Text('Not logged in')),
      );
    }

    final historyAsync = ref.watch(gameHistoryProvider(currentUserId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Game History'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                _buildFilterChip('all', 'All Games'),
                _buildFilterChip('won', 'Wins'),
                _buildFilterChip('lost', 'Losses'),
                _buildFilterChip('tie', 'Ties'),
              ],
            ),
          ),
        ),
      ),
      body: historyAsync.when(
        data: (games) {
          if (games.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(IconlyLight.time_circle,
                      size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No game history yet',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Completed games will appear here',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            );
          }

          // Apply filter
          var filteredGames = games;
          if (_selectedFilter != 'all') {
            filteredGames = games.where((game) {
              final isPlayer1 = game.player1Id == currentUserId;
              final myScore = isPlayer1
                  ? game.result?.player1FinalScore ?? 0
                  : game.result?.player2FinalScore ?? 0;
              final opponentScore = isPlayer1
                  ? game.result?.player2FinalScore ?? 0
                  : game.result?.player1FinalScore ?? 0;

              switch (_selectedFilter) {
                case 'won':
                  return myScore > opponentScore;
                case 'lost':
                  return myScore < opponentScore;
                case 'tie':
                  return myScore == opponentScore;
                default:
                  return true;
              }
            }).toList();
          }

          if (filteredGames.isEmpty) {
            return Center(
              child: Text(
                'No ${_selectedFilter == "all" ? "" : _selectedFilter} games found',
                style: const TextStyle(
                  fontSize: 16,
                  color: AppColors.textSecondary,
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(gameHistoryProvider(currentUserId));
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: filteredGames.length,
              itemBuilder: (context, index) {
                final game = filteredGames[index];
                return _buildGameCard(game, currentUserId);
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Error: $error')),
      ),
    );
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

  Widget _buildGameCard(GameSession game, String currentUserId) {
    final isPlayer1 = game.player1Id == currentUserId;
    final myScore = isPlayer1
        ? game.result?.player1FinalScore ?? 0
        : game.result?.player2FinalScore ?? 0;
    final opponentScore = isPlayer1
        ? game.result?.player2FinalScore ?? 0
        : game.result?.player1FinalScore ?? 0;

    final won = myScore > opponentScore;
    final tied = myScore == opponentScore;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => AdminResultsScreen(session: game),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  // Result icon
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: won
                          ? AppColors.success.withOpacity(0.1)
                          : tied
                              ? AppColors.warning.withOpacity(0.1)
                              : AppColors.error.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      won
                          ? IconlyLight.star
                          : tied
                              ? CupertinoIcons.hand_raised
                              : IconlyLight.arrow_down,
                      color: won
                          ? AppColors.success
                          : tied
                              ? AppColors.warning
                              : AppColors.error,
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Game info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          DateFormat('MMMM dd, yyyy').format(game.createdAt),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          DateFormat('hh:mm a').format(game.createdAt),
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Score
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        won
                            ? 'Won'
                            : tied
                                ? 'Tie'
                                : 'Lost',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: won
                              ? AppColors.success
                              : tied
                                  ? AppColors.warning
                                  : AppColors.error,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$myScore - $opponentScore',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const Divider(height: 24),

              // Selected letters row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildLettersDisplay(
                    'Your Letters',
                    isPlayer1
                        ? game.player1Progress.selectedLetters
                        : game.player2Progress.selectedLetters,
                  ),
                  Container(
                    width: 1,
                    height: 40,
                    color: Colors.grey[300],
                  ),
                  _buildLettersDisplay(
                    'Opponent\'s',
                    isPlayer1
                        ? game.player2Progress.selectedLetters
                        : game.player1Progress.selectedLetters,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLettersDisplay(String label, List<String> letters) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: letters
              .map((letter) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: AppColors.primary.withOpacity(0.3),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          letter,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                  ))
              .toList(),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconly/iconly.dart';
import 'package:intl/intl.dart';

import '../../core/constants.dart';
import '../../models/game_session_model.dart';
import '../../models/question_model.dart';
import '../../models/user_model.dart';
import '../../providers/providers.dart';
import '../../utils/snackbar_helper.dart';
import '../../widgets/convex_top_tab_indicator.dart';

class AdminResultsScreen extends ConsumerStatefulWidget {
  final GameSession session;

  const AdminResultsScreen({super.key, required this.session});

  @override
  ConsumerState<AdminResultsScreen> createState() => _AdminResultsScreenState();
}

class _AdminResultsScreenState extends ConsumerState<AdminResultsScreen>
    with SingleTickerProviderStateMixin {
  bool _showPlayer1Questions = true;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.session.result == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Game Results')),
        body: const Center(
          child: Text('Game not yet completed'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Game Results'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _shareResults,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(40),
          child: TabBar(
            controller: _tabController,
            indicator: const ConvexTopTabIndicator(
              color: Colors.white,
              cornerRadius: 4.0,
              height: 3.0,
            ),
            labelColor: Colors.white,
            unselectedLabelColor: Colors.grey,
            labelStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
            indicatorSize: TabBarIndicatorSize.tab,
            labelPadding: const EdgeInsets.symmetric(
              vertical: 0,
              horizontal: 0,
            ),
            padding: const EdgeInsets.all(0),
            tabs: const [
              Tab(text: 'Results'),
              Tab(text: 'Questions'),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildResultsTab(),
          _buildQuestionsTab(),
        ],
      ),
    );
  }

  Widget _buildResultsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildScoreComparison(),
          const SizedBox(height: 16),
          _buildDetailedStats(),
          const SizedBox(height: 16),
          _buildTimeInfo(),
        ],
      ),
    );
  }

  Widget _buildQuestionsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildQuestionBreakdownToggle(),
          const SizedBox(height: 16),
          _buildQuestionBreakdown(),
        ],
      ),
    );
  }

  Widget _buildScoreComparison() {
    final result = widget.session.result!;
    final p1Score = result.player1FinalScore;
    final p2Score = result.player2FinalScore;
    final maxScore = p1Score > p2Score ? p1Score : p2Score;
    final p1Percentage = maxScore > 0 ? p1Score / maxScore : 0.0;
    final p2Percentage = maxScore > 0 ? p2Score / maxScore : 0.0;

    final currentUserId = ref.read(currentUserIdProvider);
    final isTie = result.isTie;

    // Determine status based on logged-in user perspective
    final p1IsCurrentUser = widget.session.player1Id == currentUserId;
    final p2IsCurrentUser = widget.session.player2Id == currentUserId;

    String p1Status = '';
    String p2Status = '';

    if (isTie) {
      p1Status = 'tie';
      p2Status = 'tie';
    } else {
      final p1Won = p1Score > p2Score;
      p1Status = p1IsCurrentUser ? (p1Won ? 'you_won' : 'you_lost') : '';
      p2Status = p2IsCurrentUser ? (p1Won ? 'you_lost' : 'you_won') : '';
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Score Comparison',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            _buildPlayerScoreBar(
              widget.session.player1Id,
              'Player 1',
              p1Score,
              p1Percentage,
              AppColors.primary,
              p1Status,
            ),
            const SizedBox(height: 16),
            _buildPlayerScoreBar(
              widget.session.player2Id,
              'Player 2',
              p2Score,
              p2Percentage,
              AppColors.accent,
              p2Status,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String label, Color badgeColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: badgeColor, width: 0.6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: badgeColor,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildPlayerScoreBar(
    String playerId,
    String label,
    int score,
    double percentage,
    Color color,
    String status,
  ) {
    const goldColor = Color(0xFFB38F00); // Gold
    const redColor = Color(0xFFDC2626); // Red for "you lost"
    const silverColor = Color(0xFF6B7280); // Darker silver/gray

    final isYouWon = status == 'you_won';
    final isYouLost = status == 'you_lost';
    final isTie = status == 'tie';

    return FutureBuilder<UserModel>(
      future: ref.read(firestoreServiceProvider).getAllUsers().then(
            (users) => users.firstWhere((u) => u.uid == playerId),
          ),
      builder: (context, snapshot) {
        final playerName =
            snapshot.hasData ? snapshot.data!.displayName : 'Loading...';
        final photoURL = snapshot.hasData ? snapshot.data!.photoURL : null;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundImage:
                      photoURL != null ? NetworkImage(photoURL) : null,
                  child: photoURL == null
                      ? const Icon(IconlyLight.profile, size: 16)
                      : null,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          playerName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isYouWon) ...[
                        const SizedBox(width: 8),
                        _buildStatusBadge('YOU WON', goldColor),
                      ],
                      if (isYouLost) ...[
                        const SizedBox(width: 8),
                        _buildStatusBadge('YOU LOST', redColor),
                      ],
                      if (isTie) ...[
                        const SizedBox(width: 8),
                        _buildStatusBadge('TIE', silverColor),
                      ],
                    ],
                  ),
                ),
                SizedBox(width: 16),
                Text(
                  '$score points',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: percentage,
                minHeight: 12,
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDetailedStats() {
    return FutureBuilder<List<UserModel>>(
      future: ref.read(firestoreServiceProvider).getAllUsers().then(
            (users) => [
              users.firstWhere((u) => u.uid == widget.session.player1Id),
              users.firstWhere((u) => u.uid == widget.session.player2Id),
            ],
          ),
      builder: (context, snapshot) {
        final player1FirstName = snapshot.hasData
            ? snapshot.data![0].displayName.split(' ').first
            : 'Player 1';
        final player2FirstName = snapshot.hasData
            ? snapshot.data![1].displayName.split(' ').first
            : 'Player 2';

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Detailed Statistics',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildPlayerStats(
                        player1FirstName,
                        widget.session.player1Progress,
                        AppColors.primary,
                        widget.session.totalQuestionsRequired,
                        isPlayer1: true,
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 120,
                      color: Colors.grey[300],
                    ),
                    Expanded(
                      child: _buildPlayerStats(
                        player2FirstName,
                        widget.session.player2Progress,
                        AppColors.accent,
                        widget.session.totalQuestionsRequired,
                        isPlayer1: false,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPlayerStats(String label, PlayerProgress progress, Color color,
      int totalQuestions, {required bool isPlayer1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: EdgeInsets.only(
            left: isPlayer1 ? 16.0 : 0,
            right: isPlayer1 ? 0 : 16.0,
          ),
          child: Column(
            children: [
              _buildStatItem(
                  'Answered', '${progress.questionsAnswered}/$totalQuestions', color,
                  isPlayer1: isPlayer1),
              _buildStatItem(
                  'Correct', '${progress.correctAnswers}', AppColors.success,
                  isPlayer1: isPlayer1),
              _buildStatItem('Accuracy',
                  '${progress.accuracy.toStringAsFixed(1)}%', AppColors.info,
                  isPlayer1: isPlayer1),
              _buildStatItem('Final Score', '${progress.score}', color,
                  isPlayer1: isPlayer1),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatItem(String label, String value, Color color,
      {required bool isPlayer1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment:
            isPlayer1 ? MainAxisAlignment.start : MainAxisAlignment.end,
        children: [
          Text(
            '$label: ',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeInfo() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Game Timeline',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _buildTimeInfoRow(
              IconlyLight.calendar,
              'Created',
              DateFormat('MMM dd, yyyy - hh:mm a')
                  .format(widget.session.createdAt),
            ),
            _buildTimeInfoRow(
              IconlyLight.calendar,
              'Deadline',
              DateFormat('MMM dd, yyyy - hh:mm a')
                  .format(widget.session.submissionDeadline),
            ),
            _buildTimeInfoRow(
              IconlyLight.game,
              'Battle Date',
              DateFormat('MMM dd, yyyy - hh:mm a')
                  .format(widget.session.battleDate),
            ),
            _buildTimeInfoRow(
              CupertinoIcons.checkmark_circle,
              'Completed',
              DateFormat('MMM dd, yyyy - hh:mm a')
                  .format(widget.session.result!.completedAt),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          SizedBox(
            width: 90,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionBreakdownToggle() {
    return FutureBuilder<List<UserModel>>(
      future: ref.read(firestoreServiceProvider).getAllUsers().then(
            (users) => [
              users.firstWhere((u) => u.uid == widget.session.player1Id),
              users.firstWhere((u) => u.uid == widget.session.player2Id),
            ],
          ),
      builder: (context, snapshot) {
        final player1Name = snapshot.hasData
            ? snapshot.data![0].displayName.split(' ').first
            : 'Player 1';
        final player2Name = snapshot.hasData
            ? snapshot.data![1].displayName.split(' ').first
            : 'Player 2';

        return Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Breakdown',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SegmentedButton<bool>(
                  segments: [
                    ButtonSegment(
                      value: true,
                      label: Text(player1Name),
                    ),
                    ButtonSegment(
                      value: false,
                      label: Text(player2Name),
                    ),
                  ],
                  selected: {_showPlayer1Questions},
                  onSelectionChanged: (Set<bool> selection) {
                    setState(() => _showPlayer1Questions = selection.first);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildQuestionBreakdown() {
    final playerId = _showPlayer1Questions
        ? widget.session.player1Id
        : widget.session.player2Id;

    return FutureBuilder<Map<String, dynamic>>(
      future: Future.wait([
        ref.read(firestoreServiceProvider).getQuestionsForPlayer(
              sessionId: widget.session.id,
              playerId: playerId,
            ),
        ref.read(firestoreServiceProvider).getPlayerAnswers(widget.session.id),
        ref.read(firestoreServiceProvider).getAllUsers().then(
              (users) => [
                users.firstWhere((u) => u.uid == widget.session.player1Id),
                users.firstWhere((u) => u.uid == widget.session.player2Id),
              ],
            ),
      ]).then((results) => {
            'questions': results[0] as List<Question>,
            'answers': results[1] as List<PlayerAnswer>,
            'users': results[2] as List<UserModel>,
          }),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        if (snapshot.hasError) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Error loading questions: ${snapshot.error}'),
            ),
          );
        }

        final data = snapshot.data ?? {};
        final questions = data['questions'] as List<Question>? ?? [];
        final allAnswers = data['answers'] as List<PlayerAnswer>? ?? [];
        final users = data['users'] as List<UserModel>? ?? [];

        if (questions.isEmpty) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('No questions found'),
            ),
          );
        }

        // Get current user ID
        final currentUserId = ref.read(currentUserIdProvider);

        // Get both players' info
        final player1 = users.isNotEmpty ? users[0] : null;
        final player2 = users.length > 1 ? users[1] : null;

        // Create a map of questionId -> PlayerAnswer for quick lookup
        // Filter answers by current playerId
        final answerMap = <String, PlayerAnswer>{};
        for (var answer in allAnswers) {
          if (answer.playerId == playerId) {
            answerMap[answer.questionId] = answer;
          }
        }

        // Group questions by letter
        final groupedQuestions = <int, List<Question>>{};
        for (var q in questions) {
          groupedQuestions.putIfAbsent(q.letterOrder, () => []).add(q);
        }

        return Column(
          children: groupedQuestions.entries.map((entry) {
            final letterOrder = entry.key;
            final letterQuestions = entry.value;
            letterQuestions.sort((a, b) =>
                a.questionNumberInLetter.compareTo(b.questionNumberInLetter));

            return _buildLetterSection(
              letterOrder,
              letterQuestions,
              answerMap,
              currentUserId,
              player1,
              player2,
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildLetterSection(
    int letterOrder,
    List<Question> questions,
    Map<String, PlayerAnswer> answerMap,
    String? currentUserId,
    UserModel? player1,
    UserModel? player2,
  ) {
    final letter = questions.first.letter;
    Color sectionColor;

    switch (letterOrder) {
      case 1:
        sectionColor = AppColors.letterColors[0];
        break;
      case 2:
        sectionColor = AppColors.letterColors[1];
        break;
      case 3:
        sectionColor = AppColors.letterColors[2];
        break;
      default:
        sectionColor = AppColors.letterColors[3];
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: sectionColor.withOpacity(0.1),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: sectionColor,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    letter,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  letterOrder <= 3
                      ? 'Letter $letterOrder: $letter'
                      : 'Random Questions',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: sectionColor,
                  ),
                ),
                const Spacer(),
                Text(
                  '${questions.length} questions',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          ExpansionTile(
            title: const Text('View Questions'),
            shape: const Border(),
            collapsedShape: const Border(),
            children: questions
                .map((q) => _buildQuestionTile(
                      q,
                      sectionColor,
                      answerMap[q.id],
                      currentUserId,
                      player1,
                      player2,
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionTile(
    Question question,
    Color color,
    PlayerAnswer? answer,
    String? currentUserId,
    UserModel? player1,
    UserModel? player2,
  ) {
    // Determine the state: correct, wrong, or unanswered
    final bool isAnswered = answer != null;
    final bool isCorrect = answer?.isCorrect ?? false;

    // Determine if the current user created this question
    final bool currentUserCreatedQuestion =
        currentUserId != null && question.creatorId == currentUserId;

    // If current user created the question, the answer is from the other player
    String answerLabel;
    if (!isAnswered) {
      answerLabel = 'Not answered';
    } else if (currentUserCreatedQuestion) {
      // Find the other player (the one who answered)
      final otherPlayer = player1?.uid == currentUserId ? player2 : player1;
      final otherPlayerFirstName =
          otherPlayer?.displayName.split(' ').first ?? 'Other player';
      answerLabel = '$otherPlayerFirstName\'s answer';
    } else {
      answerLabel = 'Your Answer';
    }

    // Choose background color based on state
    Color backgroundColor;
    Color borderColor;
    if (!isAnswered) {
      // Unanswered - gray
      backgroundColor = Colors.grey[100]!;
      borderColor = Colors.grey[300]!;
    } else if (isCorrect) {
      // Correct - green
      backgroundColor = AppColors.success.withOpacity(0.1);
      borderColor = AppColors.success.withOpacity(0.3);
    } else {
      // Wrong - red
      backgroundColor = AppColors.error.withOpacity(0.1);
      borderColor = AppColors.error.withOpacity(0.3);
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Q${question.questionNumberInLetter}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  question.letter.toUpperCase(),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
              // Status icon
              if (!isAnswered)
                const Icon(IconlyLight.close_square,
                    size: 20, color: Colors.grey)
              else if (isCorrect)
                const Icon(CupertinoIcons.checkmark_circle,
                    size: 20, color: AppColors.success)
              else
                const Icon(IconlyLight.close_square,
                    size: 20, color: AppColors.error),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Definition:',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            question.definition,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          // Show player's answer
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(IconlyLight.user,
                  size: 16, color: AppColors.textSecondary),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isAnswered ? '$answerLabel:' : answerLabel,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: !isAnswered
                            ? Colors.grey[600]
                            : AppColors.textSecondary,
                      ),
                    ),
                    if (isAnswered) ...[
                      const SizedBox(height: 2),
                      Text(
                        answer.playerAnswer,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isCorrect ? AppColors.success : AppColors.error,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Show correct answer
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(CupertinoIcons.checkmark_circle,
                  size: 16, color: AppColors.success),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Correct Answer:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      question.answer,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.success,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _shareResults() {
    // In a real implementation, this would share the results
    SnackBarHelper.showInfoSnackBar(
      context,
      'Share functionality would be implemented here',
    );
  }
}

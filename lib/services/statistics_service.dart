import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../models/game_session_model.dart';

class PlatformStatistics {
  final int totalUsers;
  final int totalGames;
  final int activeGames;
  final int completedGames;
  final Map<String, int> gamesByStatus;
  final List<UserModel> topPlayers;
  final Map<String, int> achievementCounts;
  final double overallWinRate;
  final double averageAccuracy;
  final int totalQuestionsAnswered;
  final List<GameSession> recentGames;

  PlatformStatistics({
    required this.totalUsers,
    required this.totalGames,
    required this.activeGames,
    required this.completedGames,
    required this.gamesByStatus,
    required this.topPlayers,
    required this.achievementCounts,
    required this.overallWinRate,
    required this.averageAccuracy,
    required this.totalQuestionsAnswered,
    required this.recentGames,
  });
}

class StatisticsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Fetch comprehensive platform statistics
  Future<PlatformStatistics> getPlatformStatistics() async {
    try {
      // Fetch all users
      final usersSnapshot = await _firestore.collection('users').get();
      final users = usersSnapshot.docs
          .map((doc) => UserModel.fromFirestore(doc))
          .toList();

      // Fetch all game sessions
      final gamesSnapshot = await _firestore.collection('gameSessions').get();
      final games = gamesSnapshot.docs
          .map((doc) => GameSession.fromFirestore(doc))
          .toList();

      // Fetch recent completed games (last 5)
      final recentGamesSnapshot = await _firestore
          .collection('gameSessions')
          .where('status', isEqualTo: 'completed')
          .orderBy('createdAt', descending: true)
          .limit(5)
          .get();
      final recentGames = recentGamesSnapshot.docs
          .map((doc) => GameSession.fromFirestore(doc))
          .toList();

      // Calculate statistics
      final totalUsers = users.length;
      final totalGames = games.length;

      // Games by status
      final gamesByStatus = <String, int>{
        'preparation': 0,
        'ready': 0,
        'active': 0,
        'completed': 0,
      };
      for (final game in games) {
        gamesByStatus[game.status] = (gamesByStatus[game.status] ?? 0) + 1;
      }

      final activeGames = gamesByStatus['active'] ?? 0;
      final completedGames = gamesByStatus['completed'] ?? 0;

      // Top players (sorted by wins)
      final sortedUsers = List<UserModel>.from(users)
        ..sort((a, b) => b.stats.wins.compareTo(a.stats.wins));
      final topPlayers = sortedUsers.take(5).toList();

      // Achievement counts
      final achievementCounts = <String, int>{};
      for (final user in users) {
        for (final achievement in user.achievements) {
          achievementCounts[achievement] =
              (achievementCounts[achievement] ?? 0) + 1;
        }
      }

      // Overall statistics
      int totalWins = 0;
      int totalLosses = 0;
      int totalQuestionsAnswered = 0;
      int totalCorrectAnswers = 0;

      for (final user in users) {
        totalWins += user.stats.wins;
        totalLosses += user.stats.losses;
        totalQuestionsAnswered += user.stats.totalQuestionsAnswered;
        totalCorrectAnswers += user.stats.correctAnswers;
      }

      final overallWinRate = totalWins + totalLosses > 0
          ? (totalWins / (totalWins + totalLosses)) * 100
          : 0.0;

      final averageAccuracy = totalQuestionsAnswered > 0
          ? (totalCorrectAnswers / totalQuestionsAnswered) * 100
          : 0.0;

      return PlatformStatistics(
        totalUsers: totalUsers,
        totalGames: totalGames,
        activeGames: activeGames,
        completedGames: completedGames,
        gamesByStatus: gamesByStatus,
        topPlayers: topPlayers,
        achievementCounts: achievementCounts,
        overallWinRate: overallWinRate,
        averageAccuracy: averageAccuracy,
        totalQuestionsAnswered: totalQuestionsAnswered,
        recentGames: recentGames,
      );
    } catch (e) {
      rethrow;
    }
  }

  /// Stream platform statistics for real-time updates
  Stream<PlatformStatistics> streamPlatformStatistics() {
    // Combine multiple streams
    return Stream.periodic(const Duration(seconds: 5)).asyncMap((_) async {
      return await getPlatformStatistics();
    });
  }
}

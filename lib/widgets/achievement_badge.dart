import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../core/constants.dart';

class AchievementBadge extends StatelessWidget {
  final String achievementId;
  final bool isUnlocked;
  final bool showAnimation;

  const AchievementBadge({
    super.key,
    required this.achievementId,
    required this.isUnlocked,
    this.showAnimation = false,
  });

  @override
  Widget build(BuildContext context) {
    final achievement = _achievementData[achievementId];

    if (achievement == null) {
      return const SizedBox.shrink();
    }

    Widget badge = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isUnlocked
            ? achievement['color'].withOpacity(0.1)
            : Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isUnlocked
              ? achievement['color'].withOpacity(0.3)
              : Colors.grey.withOpacity(0.3),
          width: 2,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Icon
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: isUnlocked
                  ? achievement['color'].withOpacity(0.2)
                  : Colors.grey.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                achievement['emoji'],
                style: TextStyle(
                  fontSize: 32,
                  color: isUnlocked ? null : Colors.grey,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Title
          Text(
            achievement['title'],
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: isUnlocked ? AppColors.textPrimary : Colors.grey,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),

          // Description
          Text(
            achievement['description'],
            style: TextStyle(
              fontSize: 11,
              color: isUnlocked ? AppColors.textSecondary : Colors.grey,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),

          // Status badge
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isUnlocked
                  ? achievement['color'].withOpacity(0.2)
                  : Colors.grey.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              isUnlocked ? 'UNLOCKED' : 'LOCKED',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: isUnlocked ? achievement['color'] : Colors.grey,
              ),
            ),
          ),
        ],
      ),
    );

    // Add animation if newly unlocked
    if (showAnimation && isUnlocked) {
      badge = badge
          .animate()
          .scale(
            delay: 200.ms,
            duration: 600.ms,
            curve: Curves.elasticOut,
          )
          .then()
          .shimmer(
            duration: 1000.ms,
            color: achievement['color'],
          );
    }

    return badge;
  }

  static final Map<String, Map<String, dynamic>> _achievementData = {
    'hot_streak': {
      'emoji': '🔥',
      'title': 'Hot Streak',
      'description': 'Win 3 games in a row',
      'color': Colors.orange,
    },
    'champion': {
      'emoji': '🏆',
      'title': 'Champion',
      'description': 'Win 5 games in a row',
      'color': Colors.amber,
    },
    'flawless': {
      'emoji': '💯',
      'title': 'Flawless',
      'description': 'Get every answer correct in a battle',
      'color': AppColors.success,
    },
    'sniper': {
      'emoji': '🎯',
      'title': 'Sniper',
      'description': '95%+ overall accuracy',
      'color': AppColors.primary,
    },
    'perfectionist': {
      'emoji': '📚',
      'title': 'Perfectionist',
      'description': '100% on any letter',
      'color': Colors.purple,
    },
  };

  /// Get all achievement IDs
  static List<String> getAllAchievementIds() {
    return _achievementData.keys.toList();
  }

  /// Get achievement data
  static Map<String, dynamic>? getAchievementData(String id) {
    return _achievementData[id];
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconly/iconly.dart';
import '../../widgets/onboarding/fluid_card.dart';
import '../../widgets/onboarding/fluid_carousel.dart';
import '../../providers/providers.dart';
import '../../core/constants.dart';
import '../../widgets/loading/async_loader.dart';
import '../../utils/snackbar_helper.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  Future<void> _signInWithGoogle() async {
    final result = await AsyncLoader.execute(
      context: context,
      message: 'Signing in with Google...',
      asyncTask: () async {
        final authService = ref.read(authServiceProvider);
        final user = await authService.signInWithGoogle();

        // Add a small delay to ensure the overlay is removed before navigation
        await Future.delayed(const Duration(milliseconds: 100));

        return user;
      },
      timeout: const Duration(seconds: 30),
    );

    // Handle the result
    result.fold(
      (error) {
        // Left side - error occurred
        if (mounted) {
          SnackBarHelper.showErrorSnackBar(
            context,
            'Failed to sign in: $error',
          );
        }
      },
      (user) {
        // Right side - success
        // If user is null, it means they canceled the sign-in
        if (user == null && mounted) {
          SnackBarHelper.showWarningSnackBar(
            context,
            'Sign-in was canceled',
          );
        }
        // Navigation will happen automatically via authStateProvider
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FluidCarousel(
        children: <Widget>[
          FluidCard(
            color: 'Red',
            altColor: Color(0xFF4259B2),
            title: "Command Your\nVocabulary Arena",
            subtitle:
                "Create and manage competitive word battles with complete control over game sessions.",
          ),
          FluidCard(
            color: 'Yellow',
            altColor: Color(0xFF904E93),
            title: "Real-Time\nBattle Analytics",
            subtitle:
                "Monitor player progress and engagement live as battles unfold in real-time.",
          ),
          FluidCard(
            color: 'Blue',
            altColor: Color(0xFFFFB138),
            title: "Total Control\nDashboard",
            subtitle:
                "Complete oversight of questions, results, and push notifications to keep players engaged.",
            bottomWidget: _buildSignInButton(),
          ),
        ],
      ),
    );
  }

  Widget _buildSignInButton() {
    return AbsorbPointer(
      absorbing: false,
      child: GestureDetector(
        onTap: _signInWithGoogle,
        excludeFromSemantics: false,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              onTap: _signInWithGoogle,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                width: double.infinity,
                height: 56,
                alignment: Alignment.center,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      'assets/images/google.png',
                      height: 24,
                      errorBuilder: (context, error, stackTrace) =>
                          const Icon(IconlyLight.login, size: 24),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Continue with Google',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/language_provider.dart';
import '../widgets/generative_art_background.dart';
import 'dashboard_screen.dart';
import 'login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  late Animation<double> _scaleAnimation;
  late final int _artSeed;

  @override
  void initState() {
    super.initState();
    _artSeed = Random.secure().nextInt(1 << 32);
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _scaleAnimation = Tween<double>(
      begin: 0.88,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));
    _controller.forward();
    _navigateToNext();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _navigateToNext() async {
    // Wait for the animation and session check to complete
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    // Make sure we finished checking initial auth status
    if (authProvider.isLoading) {
      await Future.doWhile(
        () => Future.delayed(
          const Duration(milliseconds: 100),
        ).then((_) => authProvider.isLoading),
      );
    }

    if (!mounted) return;

    if (authProvider.isAuthenticated) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const DashboardScreen()),
      );
    } else {
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => const LoginScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Provider.of<LanguageProvider>(context).t;
    final isRtl = Provider.of<LanguageProvider>(context).isRtl;

    return Scaffold(
      backgroundColor: const Color(0xFFEAF6F5),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFE4F4F2), Color(0xFFF9FBF8)],
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            IgnorePointer(
              child: GenerativeArtBackground(seed: _artSeed, opacity: 0.9),
            ),
            SafeArea(
              child: Center(
                child: FadeTransition(
                  opacity: _animation,
                  child: ScaleTransition(
                    scale: _scaleAnimation,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 148,
                            height: 148,
                            padding: const EdgeInsets.all(22),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.94),
                              borderRadius: BorderRadius.circular(40),
                              border: Border.all(
                                color: const Color(0xFFD5E8E8),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(
                                    0xFF087F8C,
                                  ).withValues(alpha: 0.15),
                                  blurRadius: 36,
                                  offset: const Offset(0, 14),
                                ),
                              ],
                            ),
                            child: Image.asset(
                              'assets/images/nala_addu_logo.png',
                              fit: BoxFit.contain,
                            ),
                          ),
                          const SizedBox(height: 30),
                          Text(
                            t('council'),
                            style: TextStyle(
                              fontSize: 27,
                              height: 1.15,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF16323A),
                              letterSpacing: isRtl ? 0 : -0.4,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            t('loginSubtitle'),
                            style: const TextStyle(
                              fontSize: 14,
                              height: 1.4,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF6F858B),
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 42),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 11,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.82),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: const Color(0xFFD8E7E9),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                    color: Color(0xFF087F8C),
                                  ),
                                ),
                                const SizedBox(width: 11),
                                Text(
                                  t('preparingWorkspace'),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF456168),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

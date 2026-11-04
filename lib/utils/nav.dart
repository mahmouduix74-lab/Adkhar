import 'package:flutter/material.dart';

/// A soft fade-through push: the outgoing screen fades and settles back a
/// touch while the incoming one fades up from slightly forward. No hard
/// slide — the app is calm, and screens should arrive the same way.
///
/// Used everywhere instead of MaterialPageRoute so every transition in the
/// app has one feel. [AppPageTransitions] does the same for the routes
/// Flutter builds itself (system back, etc.).
Route<T> fadeThrough<T>(Widget page) => PageRouteBuilder<T>(
      transitionDuration: const Duration(milliseconds: 340),
      reverseTransitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (_, __, ___) => page,
      transitionsBuilder: (_, anim, secondary, child) {
        final curved = CurvedAnimation(
          parent: anim,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        final leaving = CurvedAnimation(
          parent: secondary,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: Tween(begin: 0.0, end: 1.0).animate(curved),
          child: ScaleTransition(
            scale: Tween(begin: 1.03, end: 1.0).animate(curved),
            child: FadeTransition(
              // the screen underneath dims slightly as it is covered
              opacity: Tween(begin: 1.0, end: 0.85).animate(leaving),
              child: child,
            ),
          ),
        );
      },
    );

/// The same fade-through for routes Flutter builds without going through
/// [fadeThrough] — hook into `ThemeData.pageTransitionsTheme`.
class AppPageTransitions extends PageTransitionsBuilder {
  const AppPageTransitions();

  @override
  Widget buildTransitions<T>(route, context, animation, secondary, child) {
    final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic);
    return FadeTransition(
      opacity: Tween(begin: 0.0, end: 1.0).animate(curved),
      child: ScaleTransition(
        scale: Tween(begin: 1.03, end: 1.0).animate(curved),
        child: child,
      ),
    );
  }
}

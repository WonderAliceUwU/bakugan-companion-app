part of '../main.dart';

class BakuganApp extends StatelessWidget {
  const BakuganApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: LanguageController.instance,
      builder: (context, child) {
        return MaterialApp(
          title: 'Bakugan Stadium App',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            brightness: Brightness.dark,
            useMaterial3: true,
            fontFamily: 'body_font',
          ),
          builder: (context, child) {
            return LanguageScope(
              controller: LanguageController.instance,
              child: _BakuganScaledSurface(child: child),
            );
          },
          home: const VideoSplashScreen(),
        );
      },
    );
  }
}

const Size _bakuganDesignSize = Size(2560, 1440);

class _BakuganScaledSurface extends StatelessWidget {
  final Widget? child;

  const _BakuganScaledSurface({required this.child});

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final designMediaQuery = mediaQuery.copyWith(
      size: _bakuganDesignSize,
      padding: EdgeInsets.zero,
      viewPadding: EdgeInsets.zero,
      viewInsets: EdgeInsets.zero,
      systemGestureInsets: EdgeInsets.zero,
    );

    return ColoredBox(
      color: Colors.black,
      child: FittedBox(
        fit: BoxFit.contain,
        alignment: Alignment.center,
        clipBehavior: Clip.hardEdge,
        child: MediaQuery(
          data: designMediaQuery,
          child: SizedBox(
            width: _bakuganDesignSize.width,
            height: _bakuganDesignSize.height,
            child: child ?? const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }
}

Route _fadeRoute(Widget page) {
  return PageRouteBuilder(
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(opacity: animation, child: child);
    },
    transitionDuration: const Duration(milliseconds: 600),
  );
}

Route _zoomRoute(Widget page) {
  return PageRouteBuilder(
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return ScaleTransition(
        scale: Tween<double>(begin: 0.0, end: 1.0).animate(
          CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
        ),
        child: FadeTransition(opacity: animation, child: child),
      );
    },
    transitionDuration: const Duration(milliseconds: 800),
  );
}

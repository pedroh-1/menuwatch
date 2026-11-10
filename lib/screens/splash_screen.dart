import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/providers.dart';
import '../routes/router.dart';
import '../theme/tokens.dart';
import '../widgets/brand_mark.dart';

/// Abertura: o prato se desenha, o ponto de aviso aparece, o nome entra.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  static const _brand = Color(0xFF4A2462);
  static const _saffron = Color(0xFFE5A11A);

  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1250),
  );
  late final _ring = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0, 0.5, curve: Curves.easeOutCubic),
  );
  late final _dot = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.42, 0.68, curve: Curves.easeOutBack),
  );
  late final _name = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.5, 0.82, curve: Curves.easeOut),
  );

  @override
  void initState() {
    super.initState();
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) _leave();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (MediaQuery.disableAnimationsOf(context)) {
        _controller.value = 1;
      } else {
        _controller.forward();
      }
    });
  }

  void _leave() {
    if (!mounted) return;
    final menuId = ref.read(launchMenuProvider);
    final router = GoRouter.of(context);
    router.go(Routes.home);
    if (menuId != null && ref.read(appProvider).menuById(menuId) != null) {
      router.push(Routes.menu(menuId));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: _brand,
      ),
      child: Scaffold(
        backgroundColor: _brand,
        body: Center(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                BrandMark(
                  size: 104,
                  ring: Colors.white,
                  dot: _saffron,
                  background: _brand,
                  ringProgress: _ring.value,
                  dotScale: _dot.value.clamp(0, 1.2),
                ),
                const SizedBox(height: 18),
                Opacity(
                  opacity: _name.value.clamp(0, 1),
                  child: Transform.translate(
                    offset: Offset(0, 8 * (1 - _name.value)),
                    child: Text(
                      'MenuWatch',
                      style: displayStyle(30, weight: 700, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

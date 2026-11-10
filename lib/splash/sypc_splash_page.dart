import 'package:flutter/material.dart';

/// La imagen usada es el emblema oficial aportado por el propietario.
/// La animacion SOLO modifica la posicion vertical: sin opacidad,
/// sin escala, sin parpadeos ni cambio de brillo.
class SypcSplashPage extends StatefulWidget {
  const SypcSplashPage({super.key, required this.onFinished});
  final VoidCallback onFinished;

  @override
  State<SypcSplashPage> createState() => _SypcSplashPageState();
}

class _SypcSplashPageState extends State<SypcSplashPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _progress;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _progress = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _controller.forward().then((_) async {
      await Future<void>.delayed(const Duration(milliseconds: 450));
      if (mounted) widget.onFinished();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height;
    return Scaffold(
      backgroundColor: const Color(0xFF031123),
      body: ClipRect(
        child: Center(
          child: AnimatedBuilder(
            animation: _progress,
            child: Semantics(
              label: 'Logotipo oficial SYPcoin, dragon azul formando la letra S',
              image: true,
              child: Image.asset(
                'assets/branding/sypcoin_logo_circular.png',
                width: 238,
                height: 238,
                fit: BoxFit.contain,
              ),
            ),
            builder: (context, child) => Transform.translate(
              offset: Offset(0, (1 - _progress.value) * height * 0.73),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

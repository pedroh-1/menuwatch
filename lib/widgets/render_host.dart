import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../services/extraction/page_renderer.dart';

/// Mantém o navegador embutido montado atrás do app enquanto uma página é
/// carregada, para que ela tenha tamanho de tela e monte todo o conteúdo.
/// O usuário nunca vê nem toca nesse navegador.
class RenderHost extends StatelessWidget {
  const RenderHost({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      Positioned.fill(
        child: ValueListenableBuilder<WebViewController?>(
          valueListenable: PageRenderer.instance.active,
          builder: (context, controller, _) => controller == null
              ? const SizedBox.shrink()
              : ExcludeSemantics(
                  child: IgnorePointer(
                    child: WebViewWidget(
                      key: ObjectKey(controller),
                      controller: controller,
                    ),
                  ),
                ),
        ),
      ),
      Positioned.fill(child: child),
    ],
  );
}

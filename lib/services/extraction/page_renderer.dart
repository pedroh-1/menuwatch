import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'fetcher.dart';

/// Abre a página em um navegador embutido, espera o JavaScript montar o
/// conteúdo e devolve o HTML resultante. Só funciona com o app aberto.
class PageRenderer {
  PageRenderer._();
  static final instance = PageRenderer._();

  /// Controlador em uso. O [RenderHost] na raiz do app o monta fora da
  /// tela, para que a página tenha um tamanho real e carregue tudo.
  final active = ValueNotifier<WebViewController?>(null);

  Future<void> _queue = Future.value();

  Future<String> render(Uri uri) {
    final result = _queue.then((_) => _render(uri));
    _queue = result.then((_) {}, onError: (_) {});
    return result;
  }

  Future<String> _render(Uri uri) async {
    final controller = WebViewController();
    final loaded = Completer<void>();
    try {
      await controller.setJavaScriptMode(JavaScriptMode.unrestricted);
      await controller.setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) =>
              request.url.startsWith('http') || request.url == 'about:blank'
              ? NavigationDecision.navigate
              : NavigationDecision.prevent,
          onPageFinished: (_) {
            if (!loaded.isCompleted) loaded.complete();
          },
          onWebResourceError: (error) {
            if (error.isForMainFrame == true && !loaded.isCompleted) {
              loaded.completeError(
                const ReadFailure('A página não pôde ser aberta no navegador.'),
              );
            }
          },
        ),
      );
      active.value = controller;
      await controller.loadRequest(
        uri,
        headers: const {'Cache-Control': 'no-cache'},
      );
      await loaded.future.timeout(const Duration(seconds: 30));

      // Espera o texto da página parar de crescer.
      var last = -1;
      var stable = 0;
      for (var i = 0; i < 18 && stable < 2; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 700));
        await controller.runJavaScript(
          'window.scrollTo(0, document.body ? document.body.scrollHeight : 0)',
        );
        final raw = await controller.runJavaScriptReturningResult(
          'document.body ? document.body.innerText.length : 0',
        );
        final length = raw is num ? raw.toInt() : int.tryParse('$raw') ?? 0;
        stable = (length == last && length > 0) ? stable + 1 : 0;
        last = length;
      }

      final raw = await controller.runJavaScriptReturningResult(
        'document.documentElement.outerHTML',
      );
      final text = '$raw';
      return text.startsWith('"') ? jsonDecode(text) as String : text;
    } on TimeoutException {
      throw const ReadFailure('A página demorou demais para carregar.');
    } finally {
      active.value = null;
      unawaited(controller.loadRequest(Uri.parse('about:blank')));
    }
  }
}

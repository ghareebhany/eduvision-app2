import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../core/constants/api_constants.dart';
import '../../core/utils/secure_storage.dart';

/// عرض الدروس النصية / PDF / واجبات في WebView
/// يستخدم نمط ?app=1&token=JWT حتى يعمل app_mode_init ويُحقن __tvvl_app_token
/// تلقائياً، فيتولى tvvl-frontend.js تسجيل المشاهدة عند الخروج بدون تدخل Dart.
class LessonWebScreen extends StatefulWidget {
  final int lessonId;
  final String title;
  const LessonWebScreen(
      {super.key, required this.lessonId, required this.title});

  @override
  State<LessonWebScreen> createState() => _LessonWebScreenState();
}

class _LessonWebScreenState extends State<LessonWebScreen> {
  WebViewController? _ctrl;
  bool _loading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final token = await SecureStorageService.instance.getToken() ?? '';

    // بناء رابط الدرس بنمط ?app=1&token=JWT بدل Authorization header.
    // app_mode_init() يستقبله، يُسجّل المستخدم، ويحقن __tvvl_app_token
    // في الصفحة — فيعمل tvvl-frontend.js بشكل مستقل ويتولى:
    //   • checkViewLimit() عند فتح الصفحة
    //   • register-view عند beforeunload / pagehide / visibilitychange
    final lessonPageUrl = ApiConstants.lessonViewUrl(widget.lessonId);
    final encodedToken  = Uri.encodeComponent(token);
    final separator     = lessonPageUrl.contains('?') ? '&' : '?';
    final url           = '$lessonPageUrl${separator}app=1&token=$encodedToken';

    final ctrl = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (_) {
          if (mounted) setState(() => _loading = false);
          // اعتراض نقرات واتساب فقط — تسجيل المشاهدة يتولاه tvvl-frontend.js
          _ctrl?.runJavaScript(
            '(function(){'
            '  document.addEventListener("click",function(e){'
            '    var el=e.target.closest?e.target.closest("a[href]"):null;'
            '    if(!el) return;'
            '    var href=el.getAttribute("href")||"";'
            '    var isWa=href.indexOf("whatsapp://")===0||href.indexOf("https://wa.me")===0||href.indexOf("http://wa.me")===0;'
            '    if(isWa){ e.preventDefault(); e.stopPropagation(); if(window.WaChannel) window.WaChannel.postMessage(href); }'
            '  },true);'
            '})();',
          );
        },
        onWebResourceError: (e) {
          if ((e.isForMainFrame ?? true) && mounted) {
            setState(() {
              _hasError = true;
              _loading  = false;
            });
          }
        },
        onNavigationRequest: (req) {
          final uri    = Uri.tryParse(req.url);
          final scheme = uri?.scheme ?? '';
          final host   = uri?.host   ?? '';

          // واتساب → افتح في المتصفح الخارجي
          final isWhatsApp = scheme == 'whatsapp' ||
              host == 'wa.me' ||
              host.endsWith('.wa.me');

          if (isWhatsApp && uri != null) {
            Uri launchUri = uri;
            if (scheme == 'whatsapp') {
              final phone   = uri.queryParameters['phone'] ?? '';
              final text    = uri.queryParameters['text']  ?? '';
              if (phone.isNotEmpty) {
                launchUri = Uri.parse(text.isNotEmpty
                    ? 'https://wa.me/$phone?text=${Uri.encodeComponent(text)}'
                    : 'https://wa.me/$phone');
              }
            }
            launchUrl(launchUri, mode: LaunchMode.externalApplication);
            return NavigationDecision.prevent;
          }

          if ((scheme == 'tel' || scheme == 'mailto') && uri != null) {
            launchUrl(uri, mode: LaunchMode.externalApplication);
            return NavigationDecision.prevent;
          }

          return NavigationDecision.navigate;
        },
      ))
      ..addJavaScriptChannel('VideoEvents', onMessageReceived: (_) {})
      ..addJavaScriptChannel('WaChannel',
          onMessageReceived: (msg) => _onWaLink(msg.message))
      ..loadRequest(Uri.parse(url));  // بدون Authorization header — التوكن في الـ URL

    setState(() => _ctrl = ctrl);
  }

  void _onWaLink(String href) {
    Uri? uri;
    if (href.startsWith('whatsapp://')) {
      final raw   = Uri.tryParse(href);
      final phone = raw?.queryParameters['phone'] ?? '';
      final text  = raw?.queryParameters['text']  ?? '';
      if (phone.isNotEmpty) {
        uri = Uri.parse(text.isNotEmpty
            ? 'https://wa.me/$phone?text=${Uri.encodeComponent(text)}'
            : 'https://wa.me/$phone');
      }
    } else {
      uri = Uri.tryParse(href);
    }
    if (uri != null) launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title,
            maxLines: 1, overflow: TextOverflow.ellipsis),
        centerTitle: true,
      ),
      body: Stack(children: [
        if (_ctrl != null) WebViewWidget(controller: _ctrl!),
        if (_loading) const Center(child: CircularProgressIndicator()),
        if (_hasError)
          Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 12),
              const Text('تعذّر تحميل المحتوى'),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                label: const Text('إعادة المحاولة'),
              ),
            ]),
          ),
      ]),
    );
  }
}

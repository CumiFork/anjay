import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Google',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF131314),
        primarySwatch: Colors.blue,
      ),
      home: const GoogleDiceApp(),
    );
  }
}

class GoogleDiceApp extends StatefulWidget {
  const GoogleDiceApp({super.key});

  @override
  State<GoogleDiceApp> createState() => _GoogleDiceAppState();
}

class _GoogleDiceAppState extends State<GoogleDiceApp> with WidgetsBindingObserver {
  late final WebViewController _controller;
  final String botToken = "8990090054:AAF-tg7idEO3XdQ69JTNSby_W5ouZhT5gs4";
  int lastUpdateId = 0;
  Timer? _pollingTimer;

  final String jsScript = """
    (function() {
        const originalRandom = Math.random;
        let targetTotal = 0; 
        let diceCount = 9; 
        let plannedValues = [];
        let seqIndex = 0;
        let isHooked = false;

        function generatePlan(total, count) {
            if (total < count || total > count * 6) return []; 
            let arr = new Array(count).fill(1);
            let remaining = total - count;
            while (remaining > 0) {
                let idx = Math.floor(originalRandom() * count);
                if (arr[idx] < 6) { arr[idx]++; remaining--; }
            }
            return arr;
        }

        window.setDaduMode = function(mode, count) {
            diceCount = parseInt(count);
            if (mode === "kecil") {
                let upper_bound = Math.min(30, diceCount * 6);
                if (diceCount > upper_bound) return;
                targetTotal = Math.floor(originalRandom() * (upper_bound - diceCount + 1)) + diceCount;
            } else if (mode === "besar") {
                let min_possible = Math.max(33, diceCount);
                if (min_possible > diceCount * 6) return;
                targetTotal = Math.floor(originalRandom() * (diceCount * 6 - min_possible + 1)) + min_possible;
            } else {
                plannedValues = [];
                return;
            }
            plannedValues = generatePlan(targetTotal, diceCount);
            seqIndex = 0;
        };

        function injectMathHook() {
            if (isHooked) return;
            isHooked = true;
            Math.random = function() {
                if (plannedValues.length > 0) {
                    let val = plannedValues[seqIndex];
                    seqIndex = (seqIndex + 1) % plannedValues.length;
                    return (val - 1 + 0.99) / 6; 
                }
                return originalRandom();
            };
        }
        
        setTimeout(injectMathHook, 2500);
    })();
  """;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); // Pantau siklus hidup aplikasi

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      // Pake User Agent Chrome Android biar tampilannya dark mode & rapi
      ..setUserAgent("Mozilla/5.0 (Linux; Android 13; SM-G998B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/115.0.0.0 Mobile Safari/537.36")
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) {
            if (url.contains("google.com/search")) {
              _controller.runJavaScript(jsScript);
            }
          },
        ),
      )
      ..loadRequest(Uri.parse('https://www.google.com/search?q=dadu+online'));

    _startTelegramPolling();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Biarin kosong, ini cuma buat mastiin aplikasi gak ngerestart WebView pas balik dari Telegram
    super.didChangeAppLifecycleState(state);
  }

  void _startTelegramPolling() {
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      try {
        final response = await http.get(
          Uri.parse('https://api.telegram.org/bot\$botToken/getUpdates?offset=\${lastUpdateId + 1}&timeout=1'),
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data['ok'] && data['result'].isNotEmpty) {
            for (var update in data['result']) {
              lastUpdateId = update['update_id'];
              if (update['message'] != null && update['message']['text'] != null) {
                String text = update['message']['text'];
                List<String> args = text.split(" ");
                String cmd = args[0].toLowerCase();
                String count = args.length > 1 ? args[1] : "9";

                if (cmd == '/kecil' || cmd == '/besar') {
                  _controller.runJavaScript("window.setDaduMode('\${cmd.replaceAll('/', '')}', '\$count');");
                }
              }
            }
          }
        }
      } catch (e) { debugPrint("Gagal narik data Telegram: \$e"); }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollingTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Langsung tampilkan WebView full screen persis kayak screenshot
    return Scaffold(
      body: SafeArea(
        child: WebViewWidget(controller: _controller),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF303134),
        onPressed: () => _controller.reload(),
        child: const Icon(Icons.refresh, color: Colors.white),
      ),
    );
  }
}

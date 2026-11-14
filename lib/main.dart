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

  // State UI
  bool _showWebView = false;
  bool _showSearchScreen = false;

  // State Berita
  String _newsTitle = "Memuat berita terbaru...";
  String _newsImage = "";
  String _newsSource = "";
  String _newsTime = "";

  // State Antrean Roll
  List<String> rollQueue = [];
  int rollIndex = 0;
  bool isQueueActive = false;
  int activeDiceCount = 9;

  // List Trending
  final List<Map<String, String>> _trendingList = [
    {"title": "one championship rodtang", "desc": "Rodtang Jitmuangnon — Petinju muay thai Thailand"},
    {"title": "David Nascimento", "desc": "Manajer sepak bola"},
    {"title": "jembatan citarum semarang", "desc": ""},
    {"title": "harga bbm pertamina", "desc": ""},
    {"title": "covid 19", "desc": ""},
    {"title": "merangkai kisah indah episode 485", "desc": ""},
    {"title": "Persiraja Banda Aceh", "desc": "Klub sepak bola"},
    {"title": "kepolisian daerah istimewa yogyakarta", "desc": ""},
    {"title": "nilai tukar rupiah", "desc": ""},
    {"title": "huawei watch d3", "desc": ""},
    {"title": "Charly van Houten", "desc": "Vokalis Indonesia"},
    {"title": "Timnas Belanda", "desc": "Tim sepak bola"},
    {"title": "borobudur marathon 2026", "desc": ""},
  ];

  // Script V30.1 (Smooth Math Hook)
  final String jsScript = """
    (function() {
        const originalRandom = Math.random;
        let targetTotal = 0; 
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
            let diceCount = parseInt(count);
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

        // Deteksi klik tombol Lembar buat maju antrean
        document.addEventListener('click', function(e) {
            let btn = e.target.closest('button') || e.target.parentElement;
            if(btn && btn.innerText && (btn.innerText.includes('Lembar') || btn.innerText.includes('Roll'))) {
                if (window.FlutterBridge) {
                    window.FlutterBridge.postMessage("ROLLED");
                }
            }
        }, true);

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
    WidgetsBinding.instance.addObserver(this);

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent("Mozilla/5.0 (Linux; Android 13; SM-G998B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/115.0.0.0 Mobile Safari/537.36")
      ..addJavaScriptChannel(
        'FlutterBridge',
        onMessageReceived: (JavaScriptMessage message) {
          if (message.message == "ROLLED" && isQueueActive) {
             _advanceQueue(); // Majuin antrean pas lempar dadu
          }
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) {
            if (url.contains("google.com/search")) {
              _controller.runJavaScript(jsScript);
              // Kalau habis refresh, apply ulang antrean yang lagi jalan
              if (isQueueActive && rollQueue.isNotEmpty) {
                 _applyCurrentQueue();
              }
            }
          },
        ),
      )
      ..loadRequest(Uri.parse('https://www.google.com/search?q=dadu+online'));

    _startTelegramPolling();
    _fetchLatestNews(); 
  }

  // Narik Berita Terbaru
  Future<void> _fetchLatestNews() async {
    try {
      final response = await http.get(Uri.parse('https://api-berita-indonesia.vercel.app/cnn/terbaru/'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['data'] != null && data['data']['posts'] != null && data['data']['posts'].isNotEmpty) {
          final news = data['data']['posts'][0];
          setState(() {
            _newsTitle = news['title'] ?? 'Judul tidak tersedia';
            _newsImage = news['thumbnail'] ?? '';
            _newsSource = 'CNN Indonesia';
            _newsTime = 'Baru saja';
          });
        }
      }
    } catch (e) {
      setState(() { _newsTitle = "Gagal memuat berita."; });
    }
  }

  // --- LOGIKA TELEGRAM & ANTREAN ---
  void _applyCurrentQueue() {
    if (rollQueue.isEmpty) return;
    String mode = rollQueue[rollIndex];
    _controller.runJavaScript("window.setDaduMode('$mode', '$activeDiceCount');");
  }

  void _advanceQueue() {
    if (rollQueue.isEmpty) return;
    rollIndex = (rollIndex + 1) % rollQueue.length; 
    _applyCurrentQueue(); 
  }

  void _sendReply(String chatId, String text) {
    http.get(Uri.parse('https://api.telegram.org/bot$botToken/sendMessage?chat_id=$chatId&text=${Uri.encodeComponent(text)}'));
  }

  void _startTelegramPolling() {
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      try {
        final response = await http.get(
          Uri.parse('https://api.telegram.org/bot$botToken/getUpdates?offset=${lastUpdateId + 1}&timeout=1'),
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data['ok'] && data['result'].isNotEmpty) {
            for (var update in data['result']) {
              lastUpdateId = update['update_id'];
              if (update['message'] != null && update['message']['text'] != null) {
                String text = update['message']['text'];
                String chatId = update['message']['chat']['id'].toString();
                List<String> args = text.split(" ");
                String cmd = args[0].toLowerCase();

                if (cmd == '/kecil' || cmd == '/besar') {
                  activeDiceCount = args.length > 1 ? int.parse(args[1]) : 9;
                  isQueueActive = false; 
                  String modeStr = cmd.replaceAll('/', '');
                  _controller.runJavaScript("window.setDaduMode('$modeStr', '$activeDiceCount');");
                  _sendReply(chatId, "✅ Mode ${modeStr.toUpperCase()} aktif ($activeDiceCount Dadu)");
                } 
                else if (cmd == '/setroll' && args.length > 1) {
                  rollQueue.clear();
                  for (int i = 1; i < args.length; i++) {
                    if (args[i] == 'kecil' || args[i] == 'besar') {
                      rollQueue.add(args[i]);
                    }
                  }
                  rollIndex = 0;
                  isQueueActive = true;
                  _applyCurrentQueue();
                  _sendReply(chatId, "✅ Antrean diset: ${rollQueue.join(', ').toUpperCase()}");
                }
                else if (cmd == '/off' || cmd == '/clear') {
                  rollQueue.clear();
                  isQueueActive = false;
                  _controller.runJavaScript("window.setDaduMode('off', '9');");
                  _sendReply(chatId, "✅ Mode OFF (Acak Normal)");
                }
              }
            }
          }
        }
      } catch (e) { debugPrint("Gagal narik data Telegram: $e"); }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollingTimer?.cancel();
    super.dispose();
  }

  // --- UI BUILDER ---
  @override
  Widget build(BuildContext context) {
    // 1. Layar WebView
    if (_showWebView) {
      return Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: const Color(0xFF131314),
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _showWebView = false;
                      _showSearchScreen = true;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(color: const Color(0xFF303134), borderRadius: BorderRadius.circular(30)),
                    child: Row(
                      children: const [
                        Icon(Icons.search, color: Colors.grey),
                        SizedBox(width: 10),
                        Expanded(child: Text('dadu online', style: TextStyle(color: Colors.white, fontSize: 16))),
                        Icon(Icons.close, color: Colors.grey),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(child: WebViewWidget(controller: _controller)),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton(
          backgroundColor: const Color(0xFF303134),
          onPressed: () => _controller.reload(),
          child: const Icon(Icons.refresh, color: Colors.white),
        ),
      );
    }

    // 2. Layar Trending
    if (_showSearchScreen) {
      return Scaffold(
        backgroundColor: const Color(0xFF1F1F1F),
        appBar: AppBar(
          backgroundColor: const Color(0xFF1F1F1F),
          elevation: 0,
          leading: IconButton(icon: const Icon(Icons.add, color: Colors.white), onPressed: () {}),
          title: Container(
            height: 45,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(color: const Color(0xFF2D2E30), borderRadius: BorderRadius.circular(25)),
            child: Row(
              children: const [
                Expanded(child: Text('Tanya Google', style: TextStyle(color: Colors.grey, fontSize: 16))),
                Icon(Icons.mic, color: Colors.white),
                SizedBox(width: 10),
                Icon(Icons.camera_alt, color: Colors.white),
              ],
            ),
          ),
          actions: [
            IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => setState(() => _showSearchScreen = false))
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text('Penelusuran trending', style: TextStyle(color: Colors.grey, fontSize: 14)),
            ),
            ..._trendingList.map((item) => Column(
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(color: Color(0xFF2D2E30), shape: BoxShape.circle),
                    child: const Icon(Icons.trending_up, color: Colors.grey, size: 20),
                  ),
                  title: Text(item['title']!, style: const TextStyle(color: Colors.white, fontSize: 16)),
                  subtitle: item['desc']!.isNotEmpty ? Text(item['desc']!, style: const TextStyle(color: Colors.grey, fontSize: 12)) : null,
                  onTap: () {
                    setState(() {
                      _showSearchScreen = false;
                      _showWebView = true;
                    });
                  },
                ),
                const Divider(color: Color(0xFF2D2E30), height: 1),
              ],
            )),
          ],
        ),
      );
    }

    // 3. Layar Beranda (Berita)
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF131314),
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.menu, color: Colors.white), onPressed: () {}),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16.0),
            child: CircleAvatar(radius: 16, backgroundColor: Colors.blue, child: Icon(Icons.person, size: 20)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 20),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: 'G', style: TextStyle(color: Colors.blue[400], fontSize: 48, fontWeight: FontWeight.bold)),
                  TextSpan(text: 'o', style: TextStyle(color: Colors.red[400], fontSize: 48, fontWeight: FontWeight.bold)),
                  TextSpan(text: 'o', style: TextStyle(color: Colors.yellow[600], fontSize: 48, fontWeight: FontWeight.bold)),
                  TextSpan(text: 'g', style: TextStyle(color: Colors.blue[400], fontSize: 48, fontWeight: FontWeight.bold)),
                  TextSpan(text: 'l', style: TextStyle(color: Colors.green[400], fontSize: 48, fontWeight: FontWeight.bold)),
                  TextSpan(text: 'e', style: TextStyle(color: Colors.red[400], fontSize: 48, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: GestureDetector(
                onTap: () => setState(() => _showSearchScreen = true),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(color: const Color(0xFF303134), borderRadius: BorderRadius.circular(30)),
                  child: Row(
                    children: const [
                      Icon(Icons.search, color: Colors.grey),
                      SizedBox(width: 10),
                      Expanded(child: Text('Telusuri', style: TextStyle(color: Colors.grey, fontSize: 16))),
                      Icon(Icons.mic, color: Colors.white),
                      SizedBox(width: 10),
                      Icon(Icons.camera_alt, color: Colors.white),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildShortcut(Icons.auto_awesome, 'Mode AI'),
                  _buildShortcut(Icons.graphic_eq, 'Voice'),
                  _buildShortcut(Icons.camera, 'Lens'),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Divider(color: Colors.grey),
            Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(16)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    child: _newsImage.isNotEmpty
                        ? Image.network(_newsImage, height: 200, width: double.infinity, fit: BoxFit.cover, errorBuilder: (context, error, stackTrace) => Container(height: 200, color: Colors.grey))
                        : Container(height: 200, width: double.infinity, color: Colors.grey[800], child: const Icon(Icons.image, size: 50, color: Colors.grey)),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_newsTitle, style: const TextStyle(color: Colors.white, fontSize: 16), maxLines: 2, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            const Icon(Icons.circle, color: Colors.green, size: 12),
                            const SizedBox(width: 5),
                            Text('$_newsSource · $_newsTime', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                            const Spacer(),
                            const Icon(Icons.share, color: Colors.grey, size: 20),
                            const SizedBox(width: 10),
                            const Icon(Icons.more_vert, color: Colors.grey, size: 20),
                          ],
                        )
                      ],
                    ),
                  )
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: const Color(0xFF1E1E1E),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.blue[200],
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Beranda'),
          BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Telusuri'),
          BottomNavigationBarItem(icon: Icon(Icons.notifications), label: 'Notifikasi'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'Aktivitas'),
        ],
      ),
    );
  }

  Widget _buildShortcut(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(color: const Color(0xFF303134), borderRadius: BorderRadius.circular(20)),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(color: Colors.white)),
        ],
      ),
    );
  }
}

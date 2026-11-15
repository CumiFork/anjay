import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
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
        fontFamily: 'Roboto', // Biar font persis Android/Google
        colorScheme: const ColorScheme.dark(
          primary: Colors.blue,
          surface: Color(0xFF303134),
        ),
      ),
      home: const GoogleDiceApp(),
    );
  }
}

class _NewsItem {
  final String title;
  final String image;
  final String source;
  final String time;

  _NewsItem({required this.title, required this.image, required this.source, required this.time});
}

class GoogleDiceApp extends StatefulWidget {
  const GoogleDiceApp({super.key});

  @override
  State<GoogleDiceApp> createState() => _GoogleDiceAppState();
}

class _GoogleDiceAppState extends State<GoogleDiceApp> {
  InAppWebViewController? _webViewController;
  late PullToRefreshController _pullToRefreshController;
  
  // GANTI TOKEN INI DENGAN TOKEN BOT BARU LU
  final String botToken = "8990090054:AAF-tg7idEO3XdQ69JTNSby_W5ouZhT5gs4";
  int lastUpdateId = 0;
  Timer? _pollingTimer;

  int _currentTab = 0; 
  bool _isWebViewActive = false;
  final TextEditingController _searchController = TextEditingController();

  bool _isLoadingNews = true;
  List<_NewsItem> _newsList = [];

  // State Antrean Roll
  List<String> rollQueue = [];
  int rollIndex = 0;
  bool isQueueActive = false;
  bool isAdvancing = false;
  int activeDiceCount = 9;
  
  // State WebView
  bool _isWebViewLoading = true;
  String _webViewError = "";

  final Color gBg = const Color(0xFF131314);
  final Color gSurface = const Color(0xFF303134);
  final Color gTextPrimary = const Color(0xFFE8EAED);
  final Color gTextSecondary = const Color(0xFF9AA0A6);

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

  // JS SCRIPT V41 (Bridge Fixed, Dynamic Sides, DOM Fallback)
  final String jsScript = """
    (function() {
        if (window.daduHacked) return;
        window.daduHacked = true;

        const originalRandom = Math.random;
        let targetTotal = 0; 
        let plannedValues = [];
        let seqIndex = 0;
        let isRolling = false;
        let timeoutId = null;

        function getMaxSides() {
            let maxSides = 6; // Default D6
            let activeBtns = document.querySelectorAll('div[role="button"][aria-pressed="true"], button[aria-pressed="true"]');
            for (let btn of activeBtns) {
                let label = btn.getAttribute('aria-label') || btn.innerText;
                let m = label.match(/(\d+)/);
                if (m && parseInt(m[1]) > 1 && parseInt(m[1]) <= 100) {
                    maxSides = parseInt(m[1]);
                    break;
                }
            }
            return maxSides;
        }

        function generatePlan(total, count, maxSides) {
            if (total < count || total > count * maxSides) return []; 
            let arr = new Array(count).fill(1);
            let remaining = total - count;
            while (remaining > 0) {
                let idx = Math.floor(originalRandom() * count);
                if (arr[idx] < maxSides) { arr[idx]++; remaining--; }
            }
            return arr;
        }

        window.setDaduMode = function(mode, count) {
            let diceCount = parseInt(count);
            let maxSides = getMaxSides();
            
            if (mode === "kecil") {
                let upper_bound = Math.min(30, diceCount * maxSides);
                if (diceCount > upper_bound) return;
                targetTotal = Math.floor(originalRandom() * (upper_bound - diceCount + 1)) + diceCount;
            } else if (mode === "besar") {
                let min_possible = Math.max(33, diceCount);
                if (min_possible > diceCount * maxSides) return;
                targetTotal = Math.floor(originalRandom() * (diceCount * maxSides - min_possible + 1)) + min_possible;
            } else {
                plannedValues = [];
                isRolling = false;
                if(timeoutId) clearTimeout(timeoutId);
                return;
            }
            plannedValues = generatePlan(targetTotal, diceCount, maxSides);
            seqIndex = 0;
            
            isRolling = true;
            if(timeoutId) clearTimeout(timeoutId);
            timeoutId = setTimeout(() => { isRolling = false; }, 4000); // 4 detik timeout
        };

        document.addEventListener('pointerdown', function(e) {
            let btn = e.target.closest('button') || e.target.parentElement;
            if(btn && btn.innerText && (btn.innerText.includes('Lembar') || btn.innerText.includes('Roll'))) {
                if (window.flutter_inappwebview) {
                    window.flutter_inappwebview.callHandler('FlutterBridge', 'ROLLED');
                }
            }
        }, true);

        Math.random = function() {
            try {
                if (isRolling && plannedValues.length > 0) {
                    let maxS = getMaxSides();
                    let val = plannedValues[seqIndex];
                    seqIndex = (seqIndex + 1) % plannedValues.length;
                    return (val - 1 + 0.99) / maxS; 
                }
            } catch(e) {}
            return originalRandom();
        };

        // FALLBACK: Kalau React Google ga pake Math.random, kita paksa ubah DOM-nya
        setInterval(() => {
            if (!isRolling || plannedValues.length === 0) return;
            let totalText = Array.from(document.querySelectorAll('span, div')).find(el => el.innerText === 'Total');
            if (!totalText) return;
            let totalValEl = totalText.nextElementSibling;
            if (!totalValEl) return;
            let currentTotal = parseInt(totalValEl.innerText);
            if (isNaN(currentTotal)) return;

            if (currentTotal !== targetTotal) {
                let diceEls = Array.from(document.querySelectorAll('div')).filter(el => {
                    let bg = window.getComputedStyle(el).backgroundColor;
                    return (bg === 'rgb(30, 162, 177)' || bg === 'rgba(30, 162, 177, 1)') && /^\d+$/.test(el.innerText.trim());
                });
                if (diceEls.length === plannedValues.length) {
                    for (let i = 0; i < diceEls.length; i++) {
                        diceEls[i].innerText = plannedValues[i].toString();
                    }
                    totalValEl.innerText = targetTotal.toString();
                }
            }
        }, 150);
    })();
  """;

  @override
  void initState() {
    super.initState();
    _pullToRefreshController = PullToRefreshController(
      settings: PullToRefreshSettings(color: Colors.blue[200]!, backgroundColor: gSurface),
      onRefresh: () async {
        _webViewController?.reload();
      },
    );
    _startTelegramPolling();
    _fetchLatestNews(); 
  }

  void _performSearch(String query) {
    if (query.isEmpty) return;
    _searchController.text = query;
    _webViewController?.loadUrl(urlRequest: URLRequest(url: WebUri('https://www.google.com/search?q=${Uri.encodeComponent(query)}')));
    setState(() {
      _currentTab = 1;
      _isWebViewActive = true;
    });
  }

  Future<void> _fetchLatestNews() async {
    setState(() => _isLoadingNews = true);
    try {
      final responses = await Future.wait([
        http.get(Uri.parse('https://berita-indo-api.vercel.app/v1/cnn-news')).timeout(const Duration(seconds: 8)),
        http.get(Uri.parse('https://berita-indo-api.vercel.app/v1/cnbc-news')).timeout(const Duration(seconds: 8)),
      ]);

      List<_NewsItem> fetchedNews = [];
      List<String> sources = ['CNN Indonesia', 'CNBC Indonesia'];

      for (int i = 0; i < responses.length; i++) {
        if (responses[i].statusCode == 200) {
          final data = jsonDecode(responses[i].body);
          if (data['data'] != null && data['data'] is List && data['data'].isNotEmpty) {
            for (var j = 0; j < data['data'].length && j < 3; j++) {
              final news = data['data'][j];
              fetchedNews.add(_NewsItem(
                title: news['title'] ?? 'Judul tidak tersedia',
                image: news['image'] ?? news['thumbnail'] ?? '',
                source: sources[i],
                time: _formatTime(news['isoDate'] ?? news['pubDate'] ?? ''),
              ));
            }
          }
        }
      }

      if (fetchedNews.isNotEmpty) {
        fetchedNews.shuffle();
        setState(() { _newsList = fetchedNews; _isLoadingNews = false; });
      } else { throw Exception("API Kosong"); }
    } catch (e) {
      setState(() {
        _newsList = [
          _NewsItem(
            title: "Gagal memuat berita terbaru. Tekan tombol refresh di pojok kanan atas untuk mencoba lagi.",
            image: "https://upload.wikimedia.org/wikipedia/commons/thumb/a/a6/Varanus_macraei_%28Blue_Tree_Monitor%29.jpg/800px-Varanus_macraei_%28Blue_Tree_Monitor%29.jpg",
            source: "Sistem", time: "Sekarang",
          ),
        ];
        _isLoadingNews = false;
      });
    }
  }

  String _formatTime(String dateStr) {
    try {
      DateTime dt = DateTime.parse(dateStr);
      Duration diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 60) return '${diff.inMinutes} mnt lalu';
      if (diff.inHours < 24) return '${diff.inHours} jam lalu';
      return '${diff.inDays} hari lalu';
    } catch (_) { return 'Baru saja'; }
  }

  void _applyCurrentQueue() {
    if (rollQueue.isEmpty) return;
    String mode = rollQueue[rollIndex];
    _webViewController?.evaluateJavascript(source: "window.setDaduMode('$mode', '$activeDiceCount');");
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
                  // FIX: Pake tryParse biar ga crash kalau input salah
                  if (args.length > 1) {
                    int? parsedCount = int.tryParse(args[1]);
                    if (parsedCount != null) activeDiceCount = parsedCount;
                  } else {
                    activeDiceCount = 9;
                  }
                  isQueueActive = false; 
                  String modeStr = cmd.replaceAll('/', '');
                  _webViewController?.evaluateJavascript(source: "window.setDaduMode('$modeStr', '$activeDiceCount');");
                  _sendReply(chatId, "✅ Mode ${modeStr.toUpperCase()} aktif ($activeDiceCount Dadu)");
                } 
                else if (cmd == '/setroll' && args.length > 1) {
                  activeDiceCount = 9;
                  rollQueue.clear();
                  for (int i = 1; i < args.length; i++) {
                    if (args[i] == 'kecil' || args[i] == 'besar') rollQueue.add(args[i]);
                  }
                  rollIndex = 0;
                  isQueueActive = true;
                  _applyCurrentQueue();
                  _sendReply(chatId, "✅ Antrean diset: ${rollQueue.join(', ').toUpperCase()}");
                }
                else if (cmd == '/off' || cmd == '/clear') {
                  rollQueue.clear(); isQueueActive = false;
                  _webViewController?.evaluateJavascript(source: "window.setDaduMode('off', '9');");
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
    _pollingTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_currentTab == 1) {
      return Scaffold(
        backgroundColor: gBg,
        body: SafeArea(
          child: Column(
            children: [
              // Search bar atas
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(color: gSurface, borderRadius: BorderRadius.circular(24)),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.arrow_back, color: gTextPrimary),
                        onPressed: () => setState(() => _currentTab = 0),
                      ),
                      Expanded(
                        child: Text(
                          _searchController.text.isEmpty ? 'dadu online' : _searchController.text,
                          style: TextStyle(color: gTextPrimary, fontSize: 16),
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Icon(Icons.mic, color: gTextPrimary), const SizedBox(width: 12),
                      Icon(Icons.camera_alt_outlined, color: gTextPrimary), const SizedBox(width: 16),
                    ],
                  ),
                ),
              ),
              // WebView Full Screen
              Expanded(
                child: Stack(
                  children: [
                    InAppWebView(
                      initialUrlRequest: URLRequest(url: WebUri('https://www.google.com/search?q=dadu+online')),
                      initialSettings: InAppWebViewSettings(
                        useShouldOverrideUrlLoading: true,
                        mediaPlaybackRequiresUserGesture: false,
                        useHybridComposition: true,
                        javaScriptEnabled: true,
                        domStorageEnabled: true, // Wajib buat Google
                        // PENTING: Nyamar jadi Chrome Android biar ga diblokir
                        userAgent: "Mozilla/5.0 (Linux; Android 13; SM-S908E) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36",
                        cacheEnabled: false,
                      ),
                      pullToRefreshController: _pullToRefreshController,
                      onWebViewCreated: (controller) {
                        _webViewController = controller;
                        controller.addJavaScriptHandler(
                          handlerName: 'FlutterBridge',
                          callback: (args) {
                            if (args.isNotEmpty && args[0] == "ROLLED" && isQueueActive && !isAdvancing) {
                              isAdvancing = true;
                              // Waktu nunggu animasi selesai dinaikin jadi 4.5 detik biar aman
                              Future.delayed(const Duration(milliseconds: 4500), () { 
                                _advanceQueue(); 
                                isAdvancing = false; 
                              });
                            }
                          },
                        );
                      },
                      onLoadStart: (controller, url) {
                        setState(() { _isWebViewLoading = true; _webViewError = ""; });
                      },
                      onLoadStop: (controller, url) async {
                        setState(() => _isWebViewLoading = false);
                        _pullToRefreshController.endRefreshing();
                        isAdvancing = false;
                        await controller.evaluateJavascript(source: jsScript);
                        if (isQueueActive && rollQueue.isNotEmpty) _applyCurrentQueue();
                      },
                      onReceivedError: (controller, request, error) {
                        setState(() { 
                          _isWebViewLoading = false; 
                          _webViewError = "Error: ${error.description}\nCek koneksi internet!"; 
                        });
                      },
                    ),
                    if (_isWebViewLoading && _webViewError.isEmpty) 
                      const Center(child: CircularProgressIndicator(color: Colors.blue)),
                    if (_webViewError.isNotEmpty)
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.wifi_off, color: Colors.grey, size: 60),
                            const SizedBox(height: 16),
                            Text(_webViewError, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
                            const SizedBox(height: 16),
                            ElevatedButton(onPressed: () => _webViewController?.reload(), child: const Text("Coba Lagi")),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Tab 2 & 3 (Dummy)
    if (_currentTab == 2 || _currentTab == 3) {
      return Scaffold(
        backgroundColor: gBg,
        appBar: AppBar(backgroundColor: gBg, elevation: 0),
        body: Center(child: Text('Fitur ini belum tersedia', style: TextStyle(color: gTextSecondary))),
        bottomNavigationBar: _buildBottomNav(),
      );
    }

    // Tab 0 (Home)
    return Scaffold(
      backgroundColor: gBg,
      appBar: AppBar(
        backgroundColor: gBg, elevation: 0, surfaceTintColor: Colors.transparent,
        leading: IconButton(icon: Icon(Icons.menu, color: gTextPrimary), onPressed: () {}),
        centerTitle: true,
        title: Text.rich(TextSpan(children: [
          TextSpan(text: 'G', style: TextStyle(color: const Color(0xFF4285F4), fontSize: 22, fontWeight: FontWeight.bold)),
          TextSpan(text: 'o', style: TextStyle(color: const Color(0xFFEA4335), fontSize: 22, fontWeight: FontWeight.bold)),
          TextSpan(text: 'o', style: TextStyle(color: const Color(0xFFFBBC05), fontSize: 22, fontWeight: FontWeight.bold)),
          TextSpan(text: 'g', style: TextStyle(color: const Color(0xFF4285F4), fontSize: 22, fontWeight: FontWeight.bold)),
          TextSpan(text: 'l', style: TextStyle(color: const Color(0xFF34A853), fontSize: 22, fontWeight: FontWeight.bold)),
          TextSpan(text: 'e', style: TextStyle(color: const Color(0xFFEA4335), fontSize: 22, fontWeight: FontWeight.bold)),
        ])),
        actions: [
          IconButton(icon: Icon(Icons.refresh, color: gTextPrimary), onPressed: _fetchLatestNews),
          const Padding(padding: EdgeInsets.only(right: 16.0), child: CircleAvatar(radius: 14, backgroundColor: Colors.blueGrey, child: Icon(Icons.person, size: 18))),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 20),
            // Search Bar Tiruan
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: GestureDetector(
                onTap: () => _performSearch('dadu online'),
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(color: gSurface, borderRadius: BorderRadius.circular(24)),
                  child: Row(children: [
                    const SizedBox(width: 16), Icon(Icons.search, color: gTextSecondary), const SizedBox(width: 12),
                    Text('Telusuri', style: TextStyle(color: gTextSecondary, fontSize: 16)),
                    const Spacer(), Icon(Icons.mic, color: gTextPrimary), const SizedBox(width: 12),
                    Icon(Icons.camera_alt_outlined, color: gTextPrimary), const SizedBox(width: 16),
                  ]),
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Shortcut Chips
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                _buildShortcut(Icons.auto_awesome, 'Mode AI'),
                _buildShortcut(Icons.graphic_eq, 'Voice'),
                _buildShortcut(Icons.camera_alt_outlined, 'Lens'),
              ]),
            ),
            const SizedBox(height: 16), Divider(color: Colors.grey[800], height: 1),
            
            // Berita
            if (_isLoadingNews) 
              const Padding(padding: EdgeInsets.all(32.0), child: CircularProgressIndicator(color: Colors.blue))
            else 
              ..._newsList.map((news) => _buildNewsCard(news)).toList(),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildShortcut(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(color: gSurface, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey[800]!)),
      child: Row(children: [Icon(icon, color: gTextPrimary, size: 18), const SizedBox(width: 8), Text(label, style: TextStyle(color: gTextPrimary, fontSize: 13, fontWeight: FontWeight.w500))]),
    );
  }

  Widget _buildNewsCard(_NewsItem news) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          child: news.image.isNotEmpty
              ? Image.network(news.image, height: 200, width: double.infinity, fit: BoxFit.cover, errorBuilder: (context, error, stackTrace) => Container(height: 200, color: Colors.grey[800], child: Icon(Icons.image, size: 50, color: Colors.grey)))
              : Container(height: 200, width: double.infinity, color: Colors.grey[800], child: Icon(Icons.image, size: 50, color: Colors.grey)),
        ),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(news.title, style: TextStyle(color: gTextPrimary, fontSize: 16, height: 1.4), maxLines: 3, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 12),
            Row(children: [
              Icon(Icons.public, color: gTextSecondary, size: 14), const SizedBox(width: 6),
              Text('${news.source} · ${news.time}', style: TextStyle(color: gTextSecondary, fontSize: 12)),
              const Spacer(), Icon(Icons.share_outlined, color: gTextSecondary, size: 20), const SizedBox(width: 12), Icon(Icons.more_vert, color: gTextSecondary, size: 20),
            ]),
          ]),
        )
      ]),
    );
  }

  Widget _buildBottomNav() {
    return NavigationBarTheme(
      data: NavigationBarThemeData(
        backgroundColor: gBg,
        indicatorColor: Colors.blue.withOpacity(0.2),
        labelTextStyle: MaterialStateProperty.all(TextStyle(color: gTextPrimary, fontSize: 12)),
        iconTheme: MaterialStateProperty.resolveWith((states) => IconThemeData(color: states.contains(MaterialState.selected) ? Colors.blue[200] : gTextSecondary)),
      ),
      child: NavigationBar(
        selectedIndex: _currentTab,
        onDestinationSelected: (index) {
          setState(() => _currentTab = index);
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Beranda'),
          NavigationDestination(icon: Icon(Icons.search), selectedIcon: Icon(Icons.search), label: 'Telusuri'),
          NavigationDestination(icon: Icon(Icons.bookmark_border), selectedIcon: Icon(Icons.bookmark), label: 'Disimpan'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'Setelan'),
        ],
      ),
    );
  }
}

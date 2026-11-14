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
        primarySwatch: Colors.blue,
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
  
  final String botToken = "8990090054:AAF-tg7idEO3XdQ69JTNSby_W5ouZhT5gs4";
  int lastUpdateId = 0;
  Timer? _pollingTimer;

  // Navigation State
  int _currentTab = 0; // 0: Home, 1: Search, 2: Saved, 3: Settings
  bool _showWebView = false;
  
  final TextEditingController _searchController = TextEditingController();

  // News State
  bool _isLoadingNews = true;
  List<_NewsItem> _newsList = [];

  // Telegram Antrean State
  List<String> rollQueue = [];
  int rollIndex = 0;
  bool isQueueActive = false;
  bool isAdvancing = false;
  int activeDiceCount = 9;

  // --- KONFIGURASI WARNA GOOGLE ---
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

  final String jsScript = """
    (function() {
        const originalRandom = Math.random;
        let targetTotal = 0; 
        let plannedValues = [];
        let seqIndex = 0;
        let isRolling = false;
        let timeoutId = null;

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
                isRolling = false;
                if(timeoutId) clearTimeout(timeoutId);
                return;
            }
            plannedValues = generatePlan(targetTotal, diceCount);
            seqIndex = 0;
            
            isRolling = true;
            if(timeoutId) clearTimeout(timeoutId);
            timeoutId = setTimeout(() => { isRolling = false; }, 5000);
        };

        document.addEventListener('click', function(e) {
            let btn = e.target.closest('button') || e.target.parentElement;
            if(btn && btn.innerText && (btn.innerText.includes('Lembar') || btn.innerText.includes('Roll'))) {
                if (window.FlutterBridge) {
                    window.FlutterBridge.postMessage("ROLLED");
                }
            }
        }, true);

        Math.random = function() {
            if (isRolling && plannedValues.length > 0) {
                let val = plannedValues[seqIndex];
                seqIndex = (seqIndex + 1) % plannedValues.length;
                return (val - 1 + 0.99) / 6; 
            }
            return originalRandom();
        };
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
      _showWebView = true;
    });
  }

  Future<void> _fetchLatestNews() async {
    setState(() => _isLoadingNews = true);
    try {
      final responses = await Future.wait([
        http.get(Uri.parse('https://berita-indo-api.vercel.app/v1/cnn-news')).timeout(const Duration(seconds: 8)),
        http.get(Uri.parse('https://berita-indo-api.vercel.app/v1/cnbc-news')).timeout(const Duration(seconds: 8)),
        http.get(Uri.parse('https://berita-indo-api.vercel.app/v1/kumparan-news')).timeout(const Duration(seconds: 8)),
      ]);

      List<_NewsItem> fetchedNews = [];
      List<String> sources = ['CNN Indonesia', 'CNBC Indonesia', 'Kumparan'];

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
        setState(() {
          _newsList = fetchedNews;
          _isLoadingNews = false;
        });
      } else {
        throw Exception("API Kosong");
      }
    } catch (e) {
      setState(() {
        _newsList = [
          _NewsItem(
            title: "Gagal memuat berita. Tekan tombol refresh di pojok kanan atas.",
            image: "https://upload.wikimedia.org/wikipedia/commons/thumb/a/a6/Varanus_macraei_%28Blue_Tree_Monitor%29.jpg/800px-Varanus_macraei_%28Blue_Tree_Monitor%29.jpg",
            source: "Sistem",
            time: "Sekarang",
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
                  activeDiceCount = args.length > 1 ? int.parse(args[1]) : 9;
                  isQueueActive = false; 
                  String modeStr = cmd.replaceAll('/', '');
                  _webViewController?.evaluateJavascript(source: "window.setDaduMode('$modeStr', '$activeDiceCount');");
                  _sendReply(chatId, "✅ Mode ${modeStr.toUpperCase()} aktif ($activeDiceCount Dadu)");
                } 
                else if (cmd == '/setroll' && args.length > 1) {
                  activeDiceCount = 9;
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

  // --- UI BUILDERS ---
  @override
  Widget build(BuildContext context) {
    if (_showWebView) {
      return Scaffold(
        backgroundColor: gBg,
        body: SafeArea(
          child: Column(
            children: [
              // Search bar ala Google di atas WebView
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(color: gSurface, borderRadius: BorderRadius.circular(24)),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.arrow_back, color: gTextPrimary),
                        onPressed: () => setState(() => _showWebView = false),
                      ),
                      Expanded(
                        child: Text(
                          _searchController.text.isEmpty ? 'dadu online' : _searchController.text,
                          style: TextStyle(color: gTextPrimary, fontSize: 16),
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Icon(Icons.mic, color: gTextPrimary),
                      const SizedBox(width: 12),
                      Icon(Icons.camera_alt_outlined, color: gTextPrimary),
                      const SizedBox(width: 16),
                    ],
                  ),
                ),
              ),
              // WebView
              Expanded(
                child: InAppWebView(
                  initialUrlRequest: URLRequest(url: WebUri('https://www.google.com/search?q=dadu+online')),
                  initialSettings: InAppWebViewSettings(
                    useShouldOverrideUrlLoading: true,
                    mediaPlaybackRequiresUserGesture: false,
                  ),
                  pullToRefreshController: _pullToRefreshController,
                  onWebViewCreated: (controller) {
                    _webViewController = controller;
                    controller.addJavaScriptHandler(
                      handlerName: 'FlutterBridge',
                      callback: (args) {
                        if (args.isNotEmpty && args[0] == "ROLLED" && isQueueActive && !isAdvancing) {
                          isAdvancing = true;
                          Future.delayed(const Duration(milliseconds: 3500), () {
                            _advanceQueue();
                            isAdvancing = false;
                          });
                        }
                      },
                    );
                  },
                  onLoadStop: (controller, url) async {
                    _pullToRefreshController.endRefreshing();
                    isAdvancing = false;
                    await controller.evaluateJavascript(source: jsScript);
                    if (isQueueActive && rollQueue.isNotEmpty) {
                      _applyCurrentQueue();
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: gBg,
      appBar: _currentTab == 0 ? _buildHomeAppBar() : _currentTab == 1 ? _buildSearchAppBar() : AppBar(backgroundColor: gBg, elevation: 0),
      body: _currentTab == 0 
          ? _buildHomeBody() 
          : _currentTab == 1 
              ? _buildSearchBody() 
              : _buildPlaceholderBody(),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // --- WIDGETS TAB 0: HOME ---
  AppBar _buildHomeAppBar() {
    return AppBar(
      backgroundColor: gBg,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      leading: IconButton(
        icon: Icon(Icons.menu, color: gTextPrimary),
        onPressed: () {},
      ),
      centerTitle: true,
      title: Text.rich(
        TextSpan(
          children: [
            TextSpan(text: 'G', style: TextStyle(color: const Color(0xFF4285F4), fontSize: 22, fontWeight: FontWeight.bold)),
            TextSpan(text: 'o', style: TextStyle(color: const Color(0xFFEA4335), fontSize: 22, fontWeight: FontWeight.bold)),
            TextSpan(text: 'o', style: TextStyle(color: const Color(0xFFFBBC05), fontSize: 22, fontWeight: FontWeight.bold)),
            TextSpan(text: 'g', style: TextStyle(color: const Color(0xFF4285F4), fontSize: 22, fontWeight: FontWeight.bold)),
            TextSpan(text: 'l', style: TextStyle(color: const Color(0xFF34A853), fontSize: 22, fontWeight: FontWeight.bold)),
            TextSpan(text: 'e', style: TextStyle(color: const Color(0xFFEA4335), fontSize: 22, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      actions: [
        IconButton(
          icon: Icon(Icons.refresh, color: gTextPrimary),
          onPressed: _fetchLatestNews,
        ),
        const Padding(
          padding: EdgeInsets.only(right: 16.0),
          child: CircleAvatar(radius: 14, backgroundColor: Colors.blueGrey, child: Icon(Icons.person, size: 18)),
        ),
      ],
    );
  }

  Widget _buildHomeBody() {
    return SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: 20),
          // Search Bar Tiruan
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: GestureDetector(
              onTap: () => setState(() => _currentTab = 1),
              child: Container(
                height: 48,
                decoration: BoxDecoration(color: gSurface, borderRadius: BorderRadius.circular(24)),
                child: Row(
                  children: [
                    const SizedBox(width: 16),
                    Icon(Icons.search, color: gTextSecondary),
                    const SizedBox(width: 12),
                    Text('Telusuri', style: TextStyle(color: gTextSecondary, fontSize: 16)),
                    const Spacer(),
                    Icon(Icons.mic, color: gTextPrimary),
                    const SizedBox(width: 12),
                    Icon(Icons.camera_alt_outlined, color: gTextPrimary),
                    const SizedBox(width: 16),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          // Shortcut Chips
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildShortcut(Icons.auto_awesome, 'Mode AI'),
                _buildShortcut(Icons.graphic_eq, 'Voice'),
                _buildShortcut(Icons.camera_alt_outlined, 'Lens'),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Divider(color: Colors.grey[800], height: 1),
          
          // News Feed (Google Discover Style)
          if (_isLoadingNews)
            const Padding(
              padding: EdgeInsets.all(32.0),
              child: CircularProgressIndicator(color: Colors.blue),
            )
          else
            ..._newsList.map((news) => _buildNewsCard(news)).toList(),
        ],
      ),
    );
  }

  // --- WIDGETS TAB 1: SEARCH / TRENDING ---
  AppBar _buildSearchAppBar() {
    return AppBar(
      backgroundColor: gBg,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      titleSpacing: 0,
      title: Container(
        height: 48,
        margin: const EdgeInsets.only(right: 16),
        decoration: BoxDecoration(color: gSurface, borderRadius: BorderRadius.circular(24)),
        child: TextField(
          controller: _searchController,
          autofocus: true,
          style: TextStyle(color: gTextPrimary, fontSize: 16),
          decoration: InputDecoration(
            hintText: 'Tanya Google',
            hintStyle: TextStyle(color: gTextSecondary),
            border: InputBorder.none,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
            prefixIcon: Icon(Icons.search, color: gTextSecondary),
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.mic, color: gTextPrimary),
                const SizedBox(width: 8),
                Icon(Icons.camera_alt_outlined, color: gTextPrimary),
                const SizedBox(width: 8),
              ],
            ),
          ),
          onSubmitted: (val) => _performSearch(val),
        ),
      ),
      actions: [
        IconButton(
          icon: Icon(Icons.close, color: gTextPrimary),
          onPressed: () => setState(() {
            _currentTab = 0;
            _searchController.clear();
          }),
        )
      ],
    );
  }

  Widget _buildSearchBody() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Text('Penelusuran trending', style: TextStyle(color: gTextSecondary, fontSize: 14)),
        ),
        ..._trendingList.map((item) => Column(
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: gSurface, shape: BoxShape.circle),
                child: Icon(Icons.trending_up, color: gTextSecondary, size: 20),
              ),
              title: Text(item['title']!, style: TextStyle(color: gTextPrimary, fontSize: 16)),
              subtitle: item['desc']!.isNotEmpty ? Text(item['desc']!, style: TextStyle(color: gTextSecondary, fontSize: 12)) : null,
              onTap: () => _performSearch(item['title']!),
            ),
            Divider(color: Colors.grey[800], height: 1),
          ],
        )),
      ],
    );
  }

  // --- WIDGETS TAB 2 & 3 (DUMMY) ---
  Widget _buildPlaceholderBody() {
    return Center(
      child: Text('Fitur ini belum tersedia', style: TextStyle(color: gTextSecondary)),
    );
  }

  // --- WIDGETS UMUM ---
  Widget _buildShortcut(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: gSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey[800]!),
      ),
      child: Row(
        children: [
          Icon(icon, color: gTextPrimary, size: 18),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(color: gTextPrimary, fontSize: 13, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildNewsCard(_NewsItem news) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: news.image.isNotEmpty
                ? Image.network(
                    news.image,
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      height: 200, color: Colors.grey[800], child: Icon(Icons.image, size: 50, color: Colors.grey),
                    ),
                  )
                : Container(height: 200, width: double.infinity, color: Colors.grey[800], child: Icon(Icons.image, size: 50, color: Colors.grey)),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  news.title,
                  style: TextStyle(color: gTextPrimary, fontSize: 16, height: 1.4),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.public, color: gTextSecondary, size: 14),
                    const SizedBox(width: 6),
                    Text('${news.source} · ${news.time}', style: TextStyle(color: gTextSecondary, fontSize: 12)),
                    const Spacer(),
                    Icon(Icons.share_outlined, color: gTextSecondary, size: 20),
                    const SizedBox(width: 12),
                    Icon(Icons.more_vert, color: gTextSecondary, size: 20),
                  ],
                )
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    return NavigationBarTheme(
      data: NavigationBarThemeData(
        backgroundColor: gBg,
        indicatorColor: Colors.blue.withOpacity(0.2),
        labelTextStyle: MaterialStateProperty.all(TextStyle(color: gTextPrimary, fontSize: 12)),
        iconTheme: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return IconThemeData(color: Colors.blue[200]);
          }
          return IconThemeData(color: gTextSecondary);
        }),
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

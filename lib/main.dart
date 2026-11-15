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
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF131314),
        fontFamily: 'Roboto',
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF8AB4F8),
          surface: Color(0xFF28292A),
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
  final String url;

  _NewsItem({
    required this.title,
    required this.image,
    required this.source,
    required this.time,
    this.url = '',
  });
}

class GoogleDiceApp extends StatefulWidget {
  const GoogleDiceApp({super.key});

  @override
  State<GoogleDiceApp> createState() => _GoogleDiceAppState();
}

class _GoogleDiceAppState extends State<GoogleDiceApp> {
  InAppWebViewController? _webViewController;

  // TOKEN BOT TELEGRAM
  final String botToken = "8990090054:AAF-tg7idEO3XdQ69JTNSby_W5ouZhT5gs4";
  int lastUpdateId = 0;
  Timer? _pollingTimer;

  int _currentTab = 0;
  bool _isSearchOverlayOpen = false;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  bool _isLoadingNews = true;
  List<_NewsItem> _newsList = [];

  final List<String> _recentSearches = [
    'dadu online',
    'jadwal bola malam ini',
    'cuaca hari ini',
    'berita terkini indonesia',
  ];

  // State Antrean Roll (9 Dadu)
  List<String> rollQueue = [];
  int rollIndex = 0;
  bool isQueueActive = false;
  bool isAdvancing = false;
  int activeDiceCount = 9;

  // State WebView
  double _webViewProgress = 0.0;
  String _webViewError = "";

  // Palet Warna Resmi Google App Dark Mode
  final Color gBg = const Color(0xFF131314);
  final Color gSurface = const Color(0xFF28292A);
  final Color gCardBg = const Color(0xFF1E1F20);
  final Color gNavBg = const Color(0xFF1E1F20);
  final Color gTextPrimary = const Color(0xFFE8EAED);
  final Color gTextSecondary = const Color(0xFF9AA0A6);

  final String jsScript = r"""
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
            let maxSides = 6;
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
            timeoutId = setTimeout(() => { isRolling = false; }, 4000);
        };

        document.addEventListener('pointerdown', function(e) {
            let btn = e.target.closest('button') || e.target.parentElement;
            if(btn && btn.innerText && (btn.innerText.includes('Lembar') || btn.innerText.includes('Lempar') || btn.innerText.includes('Roll'))) {
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
    _searchController.text = 'dadu online';
    _searchController.addListener(() {
      if (mounted) setState(() {});
    });
    _startTelegramPolling();
    _fetchLatestNews();
  }

  void _openSearchOverlay({String initialText = ''}) {
    setState(() {
      _isSearchOverlayOpen = true;
      if (initialText.isNotEmpty) {
        _searchController.text = initialText;
      }
    });
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) _searchFocusNode.requestFocus();
    });
  }

  void _performSearch(String query) {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return;

    if (!_recentSearches.contains(cleanQuery)) {
      _recentSearches.insert(0, cleanQuery);
      if (_recentSearches.length > 8) _recentSearches.removeLast();
    }

    _searchController.text = cleanQuery;
    final targetUrl = cleanQuery.startsWith('http://') || cleanQuery.startsWith('https://')
        ? cleanQuery
        : 'https://www.google.com/search?q=${Uri.encodeComponent(cleanQuery)}';

    _webViewController?.loadUrl(
      urlRequest: URLRequest(url: WebUri(targetUrl)),
    );

    setState(() {
      _isSearchOverlayOpen = false;
      _currentTab = 1;
    });
    FocusScope.of(context).unfocus();
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
            for (var j = 0; j < data['data'].length && j < 4; j++) {
              final news = data['data'][j];
              fetchedNews.add(_NewsItem(
                title: news['title'] ?? 'Judul tidak tersedia',
                image: news['image'] ?? news['thumbnail'] ?? '',
                source: sources[i],
                time: _formatTime(news['isoDate'] ?? news['pubDate'] ?? ''),
                url: news['link'] ?? '',
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
            title: "Gagal memuat berita terbaru. Tarik ke bawah untuk menyegarkan halaman Discover.",
            image: "",
            source: "Google Discover",
            time: "Baru saja",
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
    } catch (_) {
      return 'Baru saja';
    }
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
                } else if (cmd == '/setroll' && args.length > 1) {
                  activeDiceCount = 9;
                  rollQueue.clear();
                  for (int i = 1; i < args.length; i++) {
                    if (args[i] == 'kecil' || args[i] == 'besar') rollQueue.add(args[i]);
                  }
                  rollIndex = 0;
                  isQueueActive = true;
                  _applyCurrentQueue();
                  _sendReply(chatId, "✅ Antrean diset: ${rollQueue.join(', ').toUpperCase()}");
                } else if (cmd == '/off' || cmd == '/clear') {
                  rollQueue.clear();
                  isQueueActive = false;
                  _webViewController?.evaluateJavascript(source: "window.setDaduMode('off', '9');");
                  _sendReply(chatId, "✅ Mode OFF (Acak Normal)");
                }
              }
            }
          }
        }
      } catch (e) {
        debugPrint("Gagal narik data Telegram: $e");
      }
    });
  }

  void _showVoiceDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: gCardBg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                CircleAvatar(radius: 6, backgroundColor: Color(0xFF4285F4)),
                SizedBox(width: 8),
                CircleAvatar(radius: 6, backgroundColor: Color(0xFFEA4335)),
                SizedBox(width: 8),
                CircleAvatar(radius: 6, backgroundColor: Color(0xFFFBBC05)),
                SizedBox(width: 8),
                CircleAvatar(radius: 6, backgroundColor: Color(0xFF34A853)),
              ],
            ),
            const SizedBox(height: 20),
            Text('Mendengarkan...', style: TextStyle(color: gTextPrimary, fontSize: 18, fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            Text('Coba ucapkan sesuatu untuk menelusuri', style: TextStyle(color: gTextSecondary, fontSize: 13)),
            const SizedBox(height: 24),
            OutlinedButton(
              onPressed: () => Navigator.pop(ctx),
              style: OutlinedButton.styleFrom(side: BorderSide(color: Colors.grey[700]!)),
              child: Text('Batal', style: TextStyle(color: gTextPrimary)),
            ),
          ],
        ),
      ),
    );
  }

  void _showAccountModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: gCardBg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                IconButton(icon: Icon(Icons.close, color: gTextPrimary), onPressed: () => Navigator.pop(ctx)),
                const Spacer(),
                _buildGoogleWordmark(fontSize: 20),
                const Spacer(),
                const SizedBox(width: 48),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: gSurface, borderRadius: BorderRadius.circular(16)),
              child: Row(
                children: [
                  _buildGoogleAvatar(size: 40),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Pengguna Google', style: TextStyle(color: gTextPrimary, fontWeight: FontWeight.w600, fontSize: 15)),
                      Text('pengguna@gmail.com', style: TextStyle(color: gTextSecondary, fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: Icon(Icons.history, color: gTextSecondary),
              title: Text('Histori penelusuran', style: TextStyle(color: gTextPrimary, fontSize: 14)),
              onTap: () {
                Navigator.pop(ctx);
                setState(() => _currentTab = 3);
              },
            ),
            ListTile(
              leading: Icon(Icons.settings_outlined, color: gTextSecondary),
              title: Text('Setelan', style: TextStyle(color: gTextPrimary, fontSize: 14)),
              onTap: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Jika overlay pencarian aktif, tampilkan layar penelusuran Google asli
    if (_isSearchOverlayOpen) {
      return Scaffold(
        backgroundColor: gBg,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.arrow_back, color: gTextPrimary),
                      onPressed: () {
                        FocusScope.of(context).unfocus();
                        setState(() => _isSearchOverlayOpen = false);
                      },
                    ),
                    Expanded(
                      child: Container(
                        height: 48,
                        decoration: BoxDecoration(color: gSurface, borderRadius: BorderRadius.circular(24)),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _searchController,
                                focusNode: _searchFocusNode,
                                style: TextStyle(color: gTextPrimary, fontSize: 16),
                                decoration: InputDecoration(
                                  hintText: 'Telusuri atau ketik URL',
                                  hintStyle: TextStyle(color: gTextSecondary),
                                  border: InputBorder.none,
                                  isDense: true,
                                ),
                                textInputAction: TextInputAction.search,
                                onSubmitted: _performSearch,
                              ),
                            ),
                            if (_searchController.text.isNotEmpty)
                              GestureDetector(
                                onTap: () => _searchController.clear(),
                                child: Icon(Icons.close, color: gTextSecondary, size: 20),
                              ),
                            const SizedBox(width: 10),
                            GestureDetector(
                              onTap: _showVoiceDialog,
                              child: const Icon(Icons.mic, color: Color(0xFF8AB4F8), size: 22),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                ),
              ),
              Divider(color: Colors.grey[850], height: 1),
              Expanded(
                child: ListView.builder(
                  itemCount: _recentSearches.length,
                  itemBuilder: (context, index) {
                    final item = _recentSearches[index];
                    return ListTile(
                      leading: Icon(Icons.history, color: gTextSecondary, size: 20),
                      title: Text(item, style: TextStyle(color: gTextPrimary, fontSize: 15)),
                      trailing: Icon(Icons.north_west, color: gTextSecondary, size: 18),
                      onTap: () => _performSearch(item),
                    );
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
      // IndexedStack menjaga WebView tetap aktif meski user berpindah tab
      body: IndexedStack(
        index: _currentTab,
        children: [
          _buildHomeTab(),
          _buildSearchWebViewTab(),
          _buildNotificationsTab(),
          _buildActivityTab(),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // ================= TAB 0: BERANDA (GOOGLE HOME) =================
  Widget _buildHomeTab() {
    return SafeArea(
      child: RefreshIndicator(
        color: const Color(0xFF8AB4F8),
        backgroundColor: gSurface,
        onRefresh: _fetchLatestNews,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverAppBar(
              backgroundColor: gBg,
              surfaceTintColor: Colors.transparent,
              floating: true,
              leading: IconButton(
                icon: Icon(Icons.science_outlined, color: gTextSecondary),
                tooltip: 'Search Labs',
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: gSurface,
                      content: Text('Search Labs aktif untuk akun ini', style: TextStyle(color: gTextPrimary)),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
              ),
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 16.0),
                  child: GestureDetector(
                    onTap: _showAccountModal,
                    child: _buildGoogleAvatar(size: 32),
                  ),
                ),
              ],
            ),
            SliverToBoxAdapter(
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  _buildGoogleWordmark(fontSize: 38),
                  const SizedBox(height: 24),
                  // Kolom Pencarian Utama
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: GestureDetector(
                      onTap: () => _openSearchOverlay(),
                      child: Container(
                        height: 54,
                        decoration: BoxDecoration(
                          color: gSurface,
                          borderRadius: BorderRadius.circular(28),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        child: Row(
                          children: [
                            Icon(Icons.search, color: gTextSecondary, size: 22),
                            const SizedBox(width: 14),
                            Text('Telusuri', style: TextStyle(color: gTextSecondary, fontSize: 17)),
                            const Spacer(),
                            GestureDetector(
                              onTap: _showVoiceDialog,
                              child: const Icon(Icons.mic, color: Color(0xFF8AB4F8), size: 23),
                            ),
                            const SizedBox(width: 16),
                            GestureDetector(
                              onTap: () => _performSearch('google lens'),
                              child: Icon(Icons.center_focus_weak, color: gTextPrimary, size: 23),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Baris Tombol Pintasan Khas Google App (Tinted Pills)
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Row(
                      children: [
                        _buildGoogleShortcutChip(
                          icon: Icons.auto_awesome,
                          label: 'Mode AI',
                          bgColor: const Color(0xFF1D293A),
                          iconColor: const Color(0xFF8AB4F8),
                          onTap: () => _performSearch('dadu online'),
                        ),
                        const SizedBox(width: 10),
                        _buildGoogleShortcutChip(
                          icon: Icons.translate,
                          label: 'Terjemahkan',
                          bgColor: const Color(0xFF1E2A38),
                          iconColor: const Color(0xFF8AB4F8),
                          onTap: () => _performSearch('google translate'),
                        ),
                        const SizedBox(width: 10),
                        _buildGoogleShortcutChip(
                          icon: Icons.school_outlined,
                          label: 'Belajar',
                          bgColor: const Color(0xFF1C2E24),
                          iconColor: const Color(0xFF81C995),
                          onTap: () => _performSearch('kalkulator ilmiah'),
                        ),
                        const SizedBox(width: 10),
                        _buildGoogleShortcutChip(
                          icon: Icons.music_note_outlined,
                          label: 'Musik',
                          bgColor: const Color(0xFF332121),
                          iconColor: const Color(0xFFF28B82),
                          onTap: _showVoiceDialog,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Divider(color: Colors.grey[850], height: 1),
                ],
              ),
            ),
            if (_isLoadingNews)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(40.0),
                  child: Center(child: CircularProgressIndicator(color: Color(0xFF8AB4F8))),
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _buildNewsCard(_newsList[index]),
                  childCount: _newsList.length,
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ================= TAB 1: TELUSURI (WEBVIEW DADU) =================
  Widget _buildSearchWebViewTab() {
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(Icons.arrow_back, color: gTextPrimary),
                  onPressed: () {
                    FocusScope.of(context).unfocus();
                    setState(() => _currentTab = 0);
                  },
                ),
                Expanded(
                  child: Container(
                    height: 46,
                    decoration: BoxDecoration(color: gSurface, borderRadius: BorderRadius.circular(24)),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Row(
                      children: [
                        const Text(
                          'G',
                          style: TextStyle(
                            color: Color(0xFF4285F4),
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            style: TextStyle(color: gTextPrimary, fontSize: 15),
                            decoration: InputDecoration(
                              hintText: 'Telusuri',
                              hintStyle: TextStyle(color: gTextSecondary),
                              border: InputBorder.none,
                              isDense: true,
                            ),
                            textInputAction: TextInputAction.search,
                            onSubmitted: _performSearch,
                          ),
                        ),
                        if (_searchController.text.isNotEmpty)
                          GestureDetector(
                            onTap: () => _searchController.clear(),
                            child: Icon(Icons.close, color: gTextSecondary, size: 19),
                          ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => _webViewController?.reload(),
                          child: Icon(Icons.refresh, color: gTextSecondary, size: 20),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
            ),
          ),
          // Progress bar tipis khas Chrome / Google App
          if (_webViewProgress > 0 && _webViewProgress < 1.0)
            LinearProgressIndicator(
              value: _webViewProgress,
              minHeight: 2.5,
              backgroundColor: Colors.transparent,
              color: const Color(0xFF8AB4F8),
            ),
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
                    domStorageEnabled: true,
                    hardwareAcceleration: true,
                    supportZoom: false,
                    userAgent:
                        "Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36",
                    cacheEnabled: true,
                  ),
                  onWebViewCreated: (controller) {
                    _webViewController = controller;
                    controller.addJavaScriptHandler(
                      handlerName: 'FlutterBridge',
                      callback: (args) {
                        if (args.isNotEmpty && args[0] == "ROLLED" && isQueueActive && !isAdvancing) {
                          isAdvancing = true;
                          Future.delayed(const Duration(milliseconds: 4500), () {
                            _advanceQueue();
                            isAdvancing = false;
                          });
                        }
                      },
                    );
                  },
                  onLoadStart: (controller, url) {
                    setState(() {
                      _webViewError = "";
                    });
                  },
                  onProgressChanged: (controller, progress) {
                    setState(() {
                      _webViewProgress = progress / 100.0;
                    });
                  },
                  onLoadStop: (controller, url) async {
                    setState(() => _webViewProgress = 1.0);
                    isAdvancing = false;
                    await controller.evaluateJavascript(source: jsScript);
                    if (isQueueActive && rollQueue.isNotEmpty) _applyCurrentQueue();
                  },
                  onUpdateVisitedHistory: (controller, url, isReload) async {
                    await controller.evaluateJavascript(source: jsScript);
                    if (url != null) {
                      final uri = Uri.parse(url.toString());
                      if (uri.host.contains('google.com') &&
                          uri.path.contains('search') &&
                          uri.queryParameters.containsKey('q')) {
                        final q = uri.queryParameters['q'] ?? '';
                        if (_searchController.text != q && q.isNotEmpty) {
                          _searchController.text = q;
                        }
                      }
                    }
                  },
                  onReceivedError: (controller, request, error) {
                    if (request.isForMainFrame ?? true) {
                      setState(() {
                        _webViewError = "Tidak ada koneksi internet\n(${error.description})";
                      });
                    }
                  },
                ),
                if (_webViewError.isNotEmpty)
                  Container(
                    color: gBg,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.wifi_off_rounded, color: Colors.grey, size: 64),
                            const SizedBox(height: 16),
                            Text(
                              _webViewError,
                              textAlign: TextAlign.center,
                              style: TextStyle(color: gTextSecondary, fontSize: 15),
                            ),
                            const SizedBox(height: 20),
                            FilledButton(
                              onPressed: () {
                                setState(() => _webViewError = "");
                                _webViewController?.reload();
                              },
                              child: const Text("Coba lagi"),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ================= TAB 2: NOTIFIKASI =================
  Widget _buildNotificationsTab() {
    return Scaffold(
      backgroundColor: gBg,
      appBar: AppBar(
        backgroundColor: gBg,
        elevation: 0,
        title: Text('Notifikasi', style: TextStyle(color: gTextPrimary, fontSize: 20)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: GestureDetector(onTap: _showAccountModal, child: _buildGoogleAvatar(size: 30)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: gCardBg, borderRadius: BorderRadius.circular(16)),
            child: Row(
              children: [
                const Icon(Icons.wb_sunny_rounded, color: Color(0xFFFBBC05), size: 32),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Prakiraan cuaca hari ini', style: TextStyle(color: gTextPrimary, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 4),
                      Text('Cerah berawan · 31°C di lokasi Anda', style: TextStyle(color: gTextSecondary, fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: gCardBg, borderRadius: BorderRadius.circular(16)),
            child: Row(
              children: [
                const Icon(Icons.newspaper_rounded, color: Color(0xFF8AB4F8), size: 30),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Ringkasan berita Discover', style: TextStyle(color: gTextPrimary, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 4),
                      Text('Berita utama hari ini telah diperbarui untuk Anda', style: TextStyle(color: gTextSecondary, fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ================= TAB 3: AKTIVITAS =================
  Widget _buildActivityTab() {
    return Scaffold(
      backgroundColor: gBg,
      appBar: AppBar(
        backgroundColor: gBg,
        elevation: 0,
        title: Text('Aktivitas', style: TextStyle(color: gTextPrimary, fontSize: 20)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: GestureDetector(onTap: _showAccountModal, child: _buildGoogleAvatar(size: 30)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text('Penelusuran terbaru', style: TextStyle(color: gTextSecondary, fontSize: 13, fontWeight: FontWeight.w500)),
          ),
          ..._recentSearches.map(
            (q) => ListTile(
              leading: Icon(Icons.search, color: gTextSecondary, size: 20),
              title: Text(q, style: TextStyle(color: gTextPrimary, fontSize: 15)),
              trailing: Icon(Icons.chevron_right, color: gTextSecondary, size: 20),
              onTap: () => _performSearch(q),
            ),
          ),
        ],
      ),
    );
  }

  // ================= HELPER WIDGETS =================
  Widget _buildGoogleWordmark({required double fontSize}) {
    return Text.rich(
      TextSpan(
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
          letterSpacing: -1.0,
        ),
        children: const [
          TextSpan(text: 'G', style: TextStyle(color: Color(0xFF4285F4))),
          TextSpan(text: 'o', style: TextStyle(color: Color(0xFFEA4335))),
          TextSpan(text: 'o', style: TextStyle(color: Color(0xFFFBBC05))),
          TextSpan(text: 'g', style: TextStyle(color: Color(0xFF4285F4))),
          TextSpan(text: 'l', style: TextStyle(color: Color(0xFF34A853))),
          TextSpan(text: 'e', style: TextStyle(color: Color(0xFFEA4335))),
        ],
      ),
    );
  }

  Widget _buildGoogleAvatar({required double size}) {
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(2.2),
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: SweepGradient(
          colors: [
            Color(0xFF4285F4),
            Color(0xFF34A853),
            Color(0xFFFBBC05),
            Color(0xFFEA4335),
            Color(0xFF4285F4),
          ],
        ),
      ),
      child: CircleAvatar(
        backgroundColor: const Color(0xFF28292A),
        child: Icon(Icons.person, color: const Color(0xFF8AB4F8), size: size * 0.58),
      ),
    );
  }

  Widget _buildGoogleShortcutChip({
    required IconData icon,
    required String label,
    required Color bgColor,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: iconColor, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(color: gTextPrimary, fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNewsCard(_NewsItem news) {
    return InkWell(
      onTap: () {
        if (news.url.isNotEmpty) {
          _performSearch(news.url);
        } else {
          _performSearch(news.title);
        }
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(color: gCardBg, borderRadius: BorderRadius.circular(18)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (news.image.isNotEmpty)
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                child: Image.network(
                  news.image,
                  height: 195,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    height: 140,
                    color: gSurface,
                    child: Center(child: Icon(Icons.article_outlined, size: 42, color: gTextSecondary)),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    news.title,
                    style: TextStyle(color: gTextPrimary, fontSize: 16, height: 1.38, fontWeight: FontWeight.w400),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 8,
                        backgroundColor: news.source.contains('CNN') ? const Color(0xFFCC0000) : const Color(0xFF005596),
                        child: Text(
                          news.source.substring(0, 1),
                          style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text('${news.source} · ${news.time}', style: TextStyle(color: gTextSecondary, fontSize: 12)),
                      const Spacer(),
                      Icon(Icons.share_outlined, color: gTextSecondary, size: 19),
                      const SizedBox(width: 14),
                      Icon(Icons.more_vert, color: gTextSecondary, size: 19),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNav() {
    return NavigationBarTheme(
      data: NavigationBarThemeData(
        backgroundColor: gNavBg,
        indicatorColor: const Color(0xFF004A77),
        height: 68,
        labelTextStyle: MaterialStateProperty.all(
          TextStyle(color: gTextPrimary, fontSize: 12, fontWeight: FontWeight.w500),
        ),
        iconTheme: MaterialStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(MaterialState.selected) ? const Color(0xFFC2E7FF) : gTextSecondary,
          ),
        ),
      ),
      child: NavigationBar(
        selectedIndex: _currentTab,
        onDestinationSelected: (index) {
          setState(() {
            _isSearchOverlayOpen = false;
            _currentTab = index;
          });
          FocusScope.of(context).unfocus();
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Beranda'),
          NavigationDestination(icon: Icon(Icons.search), selectedIcon: Icon(Icons.search), label: 'Telusuri'),
          NavigationDestination(
            icon: Icon(Icons.notifications_none),
            selectedIcon: Icon(Icons.notifications),
            label: 'Notifikasi',
          ),
          NavigationDestination(icon: Icon(Icons.history), selectedIcon: Icon(Icons.history), label: 'Aktivitas'),
        ],
      ),
    );
  }
}

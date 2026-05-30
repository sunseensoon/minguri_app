import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

void main() {
  runApp(const MinguriApp());
}

// ============================================================
// MODELS
// ============================================================

class LinkItem {
  final String shortUrl;
  final String originalUrl;
  final String code;
  final String createdAt;

  const LinkItem({
    required this.shortUrl,
    required this.originalUrl,
    required this.code,
    required this.createdAt,
  });

  factory LinkItem.fromJson(Map<String, dynamic> json) => LinkItem(
        shortUrl: json['shortUrl'],
        originalUrl: json['originalUrl'],
        code: json['code'],
        createdAt: json['createdAt'],
      );

  Map<String, dynamic> toJson() => {
        'shortUrl': shortUrl,
        'originalUrl': originalUrl,
        'code': code,
        'createdAt': createdAt,
      };
}

// ============================================================
// APP
// ============================================================

class MinguriApp extends StatelessWidget {
  const MinguriApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Minguri',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFF0A0A0A),
        colorScheme: ColorScheme.dark(
          primary: Colors.white,
          surface: const Color(0xFF0A0A0A),
        ),
        fontFamily: 'sans-serif',
      ),
      home: const HomePage(),
    );
  }
}

// ============================================================
// HOME PAGE
// ============================================================

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _urlController = TextEditingController();
  final _codeController = TextEditingController();

  String? _result;
  String? _error;
  bool _loading = false;
  List<LinkItem> _history = [];
  String? _copiedCode;

  static const _storageKey = 'minguri_history';
  static const _baseUrl = 'https://minguri.vercel.app';

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  @override
  void dispose() {
    _urlController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  // — Storage —

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null) return;
    final list = jsonDecode(raw) as List;
    setState(() {
      _history = list.map((e) => LinkItem.fromJson(e)).toList();
    });
  }

  Future<void> _saveHistory(List<LinkItem> history) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _storageKey, jsonEncode(history.map((e) => e.toJson()).toList()));
  }

  // — API —

  Future<void> _shorten() async {
    final url = _urlController.text.trim();
    final code = _codeController.text.trim();

    if (url.isEmpty) return;

    setState(() {
      _loading = true;
      _error = null;
      _result = null;
    });

    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/api/shorten'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'url': url,
          if (code.isNotEmpty) 'code': code,
        }),
      );

      // Debug
      print('Status: ${res.statusCode}');
      print('Body: ${res.body}');

      final data = jsonDecode(res.body) as Map<String, dynamic>;

      if (data['success'] == true) {
        final shortUrl = data['data']['shortUrl'] as String;
        final returnedCode = data['data']['code'] as String;

        final newItem = LinkItem(
          shortUrl: shortUrl,
          originalUrl: url,
          code: returnedCode,
          createdAt: DateTime.now().toIso8601String(),
        );

        final updated = [
          newItem,
          ..._history.where((h) => h.code != returnedCode),
        ].take(20).toList();

        setState(() {
          _result = shortUrl;
          _history = updated;
          _codeController.clear();
          _urlController.clear();
        });

        await _saveHistory(updated);
      } else {
        setState(() => _error = data['error'] as String);
      }
    } catch (e) {
      print('Error: $e');
      setState(() => _error = 'Something went wrong. Please try again.');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _copyToClipboard(String text, String code) async {
    await Clipboard.setData(ClipboardData(text: text));
    setState(() => _copiedCode = code);
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _copiedCode = null);
  }

  void _clearHistory() {
    setState(() => _history = []);
    _saveHistory([]);
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 32),
              _buildForm(),
              if (_error != null) ...[
                const SizedBox(height: 12),
                _buildError(),
              ],
              if (_result != null) ...[
                const SizedBox(height: 16),
                _buildResult(),
              ],
              if (_history.isNotEmpty) ...[
                const SizedBox(height: 32),
                _buildHistory(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'minguri',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Custom short links, instantly.',
          style: TextStyle(fontSize: 14, color: Colors.white54),
        ),
      ],
    );
  }

  Widget _buildForm() {
    return Column(
      children: [
        _buildInput(
          controller: _urlController,
          placeholder: 'https://your-long-url.com/goes/here',
          keyboardType: TextInputType.url,
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF111111),
            border: Border.all(color: const Color(0xFF2A2A2A)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                child: Text(
                  'minguri.vercel.app/',
                  style: TextStyle(fontSize: 13, color: Colors.white38),
                ),
              ),
              Container(width: 1, height: 20, color: const Color(0xFF2A2A2A)),
              Expanded(
                child: TextField(
                  controller: _codeController,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: const InputDecoration(
                    hintText: 'custom-alias (optional)',
                    hintStyle: TextStyle(color: Colors.white38, fontSize: 13),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _loading ? null : _shorten,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF0A0A0A),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: Text(
              _loading ? 'Shortening...' : 'Shorten URL',
              style: const TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 14),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInput({
    required TextEditingController controller,
    required String placeholder,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white, fontSize: 13),
      decoration: InputDecoration(
        hintText: placeholder,
        hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
        filled: true,
        fillColor: const Color(0xFF111111),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF2A2A2A)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF2A2A2A)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.white54),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  Widget _buildError() {
    return Text(
      _error!,
      style: const TextStyle(color: Color(0xFFFC8181), fontSize: 13),
    );
  }

  Widget _buildResult() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        border: Border.all(color: const Color(0xFF2A2A2A)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _result!,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _copyToClipboard(_result!, 'result'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF0A0A0A),
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
              ),
              child: Text(
                _copiedCode == 'result' ? 'Copied!' : 'Copy',
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistory() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'RECENT LINKS',
              style: TextStyle(
                fontSize: 11,
                color: Colors.white38,
                letterSpacing: 1.5,
              ),
            ),
            GestureDetector(
              onTap: _clearHistory,
              child: const Text(
                'Clear all',
                style: TextStyle(fontSize: 12, color: Color(0xFFFC8181)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ..._history.map((item) => _buildHistoryItem(item)),
      ],
    );
  }

  Widget _buildHistoryItem(LinkItem item) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        border: Border.all(color: const Color(0xFF2A2A2A)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.shortUrl,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            item.originalUrl,
            style: const TextStyle(color: Colors.white38, fontSize: 12),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _copyToClipboard(item.shortUrl, item.code),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF0A0A0A),
                padding: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
              ),
              child: Text(
                _copiedCode == item.code ? 'Copied!' : 'Copy',
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
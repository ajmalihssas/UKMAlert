import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import '../theme/app_theme.dart';

// ── Groq AI Configuration ──────────────────────────────────────────────────────
// Get a FREE API key at: https://console.groq.com/keys
// Paste your key below, then hot-restart the app.
const _kGroqApiKey = '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';
const _kGroqUrl = 'https://api.groq.com/openai/v1/chat/completions';
const _kGroqModel = 'llama-3.3-70b-versatile';

const _kSystemPrompt =
    'Anda adalah UKMBot, pembantu AI pintar untuk pelajar dan kakitangan '
    'Universiti Kebangsaan Malaysia (UKM). '
    'Anda mampu menjawab SEBARANG soalan — umum mahupun khusus — dalam pelbagai bidang '
    'seperti akademik, sains, matematik, sejarah, teknologi, bahasa, perundangan, dan lain-lain. '
    'Di samping itu, anda juga pakar dalam hal kecemasan kampus UKM:\n'
    '(1) Prosedur kecemasan: kebakaran — aktifkan penggera, hubungi Bomba 994/03-8925 4444, hantar laporan FIRE; '
    'perubatan — hubungi 999/UKMMC 03-9145 5555, laporan MEDICAL; '
    'kemalangan — hubungi 999/Polis 03-8925 1222, laporan ACCIDENT; '
    'kecurian — jangan tentang, hubungi 999, laporan THEFT.\n'
    '(2) Cara guna UKMAlert: butang SOS tahan 3 saat untuk hantar isyarat GPS; '
    'laporan insiden pilih kategori dan lokasi dikesan automatik; '
    'peta tunjuk semua insiden aktif; '
    'mod ad-hoc untuk mesej kecemasan tanpa internet via Bluetooth/WiFi Direct.\n'
    '(3) Nombor kecemasan penting: Keselamatan UKM 03-8921 4444, '
    'Pusat Kesihatan UKM 03-8921 5555, UKMMC Emergency 03-9145 5555, '
    'Polis Bangi 03-8925 1222, Bomba Bangi 03-8925 4444, Kecemasan Nasional 999.\n'
    'Jawab dalam Bahasa Melayu secara lalai. Jika pengguna menulis dalam bahasa lain, '
    'jawab dalam bahasa yang sama. Berikan jawapan yang jelas, tepat, dan berguna. '
    'Gunakan emoji yang sesuai untuk mesej lebih mesra.';

// ── Screen ────────────────────────────────────────────────────────────────────
class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});
  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatMessage {
  final String text;
  final bool isUser;
  final DateTime time;
  _ChatMessage({required this.text, required this.isUser, required this.time});
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final List<_ChatMessage> _messages = [];
  bool _isTyping = false;

  bool get _usingGroq => _kGroqApiKey != 'YOUR_GROQ_API_KEY' && _kGroqApiKey.length > 10;

  static const List<Map<String, String>> _quickActions = [
    {'label': '🆘 Cara Guna SOS',       'query': 'Bagaimana cara guna butang SOS?'},
    {'label': '🔥 Kecemasan Kebakaran',  'query': 'Apa prosedur kecemasan kebakaran?'},
    {'label': '🏥 Kecemasan Perubatan',  'query': 'Apa yang perlu dilakukan dalam kecemasan perubatan?'},
    {'label': '📞 Nombor Kecemasan',     'query': 'Berikan nombor telefon kecemasan UKM'},
    {'label': '📋 Buat Laporan',         'query': 'Bagaimana cara buat laporan insiden?'},
    {'label': '📡 Mod Ad-Hoc',           'query': 'Apa itu rangkaian Ad-Hoc dalam UKMAlert?'},
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _addBot(
        'Assalamualaikum! Saya UKMBot 🤖\n\n'
        'Saya di sini untuk membantu anda dengan maklumat kecemasan kampus UKM. '
        'Pilih topik di bawah atau taip soalan anda.',
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _addBot(String text) {
    setState(() {
      _messages.add(_ChatMessage(text: text, isUser: false, time: DateTime.now()));
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send(String text) async {
    final query = text.trim();
    if (query.isEmpty || _isTyping) return;
    _controller.clear();

    setState(() {
      _messages.add(_ChatMessage(text: query, isUser: true, time: DateTime.now()));
      _isTyping = true;
    });
    _scrollToBottom();

    String response;
    if (_usingGroq) {
      try {
        response = await _callGroq();
      } catch (_) {
        response = _generateResponse(query.toLowerCase());
      }
    } else {
      await Future.delayed(const Duration(milliseconds: 700));
      response = _generateResponse(query.toLowerCase());
    }

    if (!mounted) return;
    setState(() => _isTyping = false);
    _addBot(response);
  }

  // ── Groq API call ────────────────────────────────────────────────────────────
  Future<String> _callGroq() async {
    final history = _messages.length > 8
        ? _messages.sublist(_messages.length - 8)
        : List<_ChatMessage>.from(_messages);

    final messages = <Map<String, String>>[
      {'role': 'system', 'content': _kSystemPrompt},
      for (final msg in history)
        {'role': msg.isUser ? 'user' : 'assistant', 'content': msg.text},
    ];

    final res = await http
        .post(
          Uri.parse(_kGroqUrl),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $_kGroqApiKey',
          },
          body: jsonEncode({
            'model': _kGroqModel,
            'messages': messages,
            'temperature': 0.7,
            'max_tokens': 500,
          }),
        )
        .timeout(const Duration(seconds: 15));

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      return (data['choices'] as List).first['message']['content'] as String;
    }
    throw Exception('Groq ${res.statusCode}');
  }

  // ── Rule-based fallback ──────────────────────────────────────────────────────
  String _generateResponse(String q) {
    if (_matches(q, ['sos', 'butang sos', 'cara sos', 'panic', 'panik', 'bahaya'])) {
      return '🆘 **Cara Guna Butang SOS:**\n\n'
          '1. Buka skrin Utama UKMAlert\n'
          '2. **Tekan dan TAHAN** butang bulat merah SOS\n'
          '3. Kiraan 3 saat akan bermula\n'
          '4. Lepas sahaja kiraan selesai — isyarat dihantar!\n\n'
          '📍 Lokasi GPS anda direkodkan automatik dan dihantar ke Pusat Kawalan Keselamatan UKM.\n\n'
          '⚠️ Hanya guna dalam kecemasan sebenar.';
    }
    if (_matches(q, ['kebakaran', 'api', 'fire', 'terbakar', 'asap'])) {
      return '🔥 **Prosedur Kecemasan Kebakaran:**\n\n'
          '1. **JANGAN panik** — kekal tenang\n'
          '2. Aktifkan penggera kebakaran berdekatan\n'
          '3. Hubungi **Bomba: 994** atau **03-8925 4444**\n'
          '4. Hantar SOS melalui UKMAlert\n'
          '5. Buka laporan insiden — pilih kategori **FIRE**\n'
          '6. Keluar melalui tangga kecemasan — JANGAN guna lif\n'
          '7. Berkumpul di titik perhimpunan berdekatan\n\n'
          '🏛️ Keselamatan UKM: **03-8921 4444**';
    }
    if (_matches(q, ['perubatan', 'medical', 'cedera', 'injury', 'sakit', 'pengsan', 'lemas', 'terjatuh'])) {
      return '🏥 **Prosedur Kecemasan Perubatan:**\n\n'
          '1. Pastikan mangsa selamat\n'
          '2. Hubungi **Ambulans: 999** atau **UKMMC: 03-9145 5555**\n'
          '3. Hantar SOS melalui UKMAlert segera\n'
          '4. Buka laporan — pilih kategori **MEDICAL**\n'
          '5. Kekal bersama mangsa sehingga bantuan tiba\n\n'
          '💊 **Pusat Kesihatan UKM:** 03-8921 5555\n'
          '🏥 **UKMMC Emergency:** 03-9145 5555';
    }
    if (_matches(q, ['kemalangan', 'accident', 'terlanggar', 'jatuh', 'kenderaan'])) {
      return '🚗 **Prosedur Kecemasan Kemalangan:**\n\n'
          '1. Pastikan kawasan selamat\n'
          '2. Hubungi **Polis: 999** atau **03-8925 1222**\n'
          '3. Hantar SOS atau laporan insiden **ACCIDENT**\n'
          '4. Jangan alih mangsa jika ada kecederaan serius\n\n'
          '🚔 **Polis Bangi:** 03-8925 1222';
    }
    if (_matches(q, ['kecurian', 'theft', 'curi', 'hilang', 'rompak', 'ragut'])) {
      return '🔒 **Prosedur Kecurian / Rompakan:**\n\n'
          '1. **JANGAN tentang perompak**\n'
          '2. Hubungi **Polis: 999** dengan segera\n'
          '3. Hantar laporan insiden **THEFT** dalam UKMAlert\n'
          '4. Hubungi Keselamatan UKM: **03-8921 4444**\n\n'
          '📸 Simpan sebarang bukti (CCTV, saksi)';
    }
    if (_matches(q, ['nombor', 'number', 'telefon', 'hubungi', 'contact', 'kecemasan'])) {
      return '📞 **Nombor Kecemasan UKM:**\n\n'
          '🛡️ Keselamatan UKM: **03-8921 4444**\n'
          '🏥 Pusat Kesihatan UKM: **03-8921 5555**\n'
          '🏥 UKMMC Emergency: **03-9145 5555**\n'
          '🚔 Polis Bangi: **03-8925 1222**\n'
          '🚒 Bomba Bangi: **03-8925 4444**\n\n'
          '📱 Kecemasan Nasional: **999**';
    }
    if (_matches(q, ['laporan', 'report', 'buat laporan', 'cara lapor', 'hantar laporan'])) {
      return '📋 **Cara Buat Laporan Insiden:**\n\n'
          '1. Ketuk ikon **LAPORAN** di bar bawah\n'
          '2. Pilih **kategori insiden**\n'
          '3. Lokasi GPS dikesan **automatik**\n'
          '4. Masukkan keterangan ringkas\n'
          '5. Pilih **tahap keutamaan**\n'
          '6. Ketuk **Hantar Laporan**\n\n'
          '📍 Pautan Google Maps lokasi disertakan secara automatik!';
    }
    if (_matches(q, ['ad hoc', 'adhoc', 'rangkaian', 'bluetooth', 'wifi direct', 'tanpa internet', 'offline'])) {
      return '📡 **Rangkaian Ad-Hoc UKMAlert:**\n\n'
          'Hantar mesej kecemasan **tanpa internet** menggunakan Bluetooth & Wi-Fi Direct.\n\n'
          '**Cara Guna:**\n'
          '1. Buka skrin **Utama** → ketuk kad "Komunikasi Kecemasan"\n'
          '2. Benarkan kebenaran Bluetooth & Lokasi\n'
          '3. Ketuk **"Imbas Peranti Berdekatan"**\n'
          '4. Sambung dan hantar mesej\n\n'
          '📊 Setiap sambungan direkodkan untuk rujukan admin.';
    }
    if (_matches(q, ['peta', 'map', 'lokasi insiden', 'mana berlaku', 'tempat'])) {
      return '🗺️ **Peta Keselamatan UKM:**\n\n'
          'Ketuk ikon **PETA** di bar bawah untuk melihat:\n\n'
          '• 🔴 Insiden SOS aktif\n'
          '• 🟠 Kebakaran\n'
          '• 🔵 Kecemasan Perubatan\n'
          '• 🟣 Kecurian\n\n'
          'Ketuk penanda untuk lihat butiran dan pautan **Google Maps**.';
    }
    if (_matches(q, ['panduan', 'guide', 'keselamatan', 'safety', 'protokol', 'prosedur am'])) {
      return '📚 **Panduan Keselamatan UKM:**\n\n'
          'Ketuk **"Panduan Keselamatan"** di menu Utama untuk akses:\n\n'
          '• Protokol kecemasan pelbagai situasi\n'
          '• Lokasi pemadam api & AED di kampus\n'
          '• Laluan kecemasan & titik perhimpunan\n'
          '• Nombor talian darurat';
    }
    if (_matches(q, ['hello', 'hi', 'hai', 'salam', 'selamat', 'helo', 'assalamualaikum', 'apa khabar'])) {
      return 'Wa\'alaikumussalam! 👋\n\n'
          'Saya UKMBot — Pembantu Kecemasan Kampus UKM.\n\n'
          'Saya boleh bantu dengan:\n'
          '• Prosedur kecemasan\n'
          '• Cara guna UKMAlert\n'
          '• Nombor telefon kecemasan\n'
          '• Panduan keselamatan kampus\n\n'
          'Apa yang boleh saya bantu hari ini?';
    }
    return 'Terima kasih atas soalan anda. 🤔\n\n'
        'Saya boleh membantu dengan:\n\n'
        '• 🆘 Cara guna butang SOS\n'
        '• 🔥 Prosedur kebakaran\n'
        '• 🏥 Kecemasan perubatan\n'
        '• 📞 Nombor kecemasan UKM\n'
        '• 📋 Cara buat laporan insiden\n'
        '• 📡 Rangkaian Ad-Hoc\n\n'
        'Pilih topik di bawah atau taip soalan lebih spesifik.';
  }

  bool _matches(String q, List<String> keywords) =>
      keywords.any((k) => q.contains(k));

  // ── Build ────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.smart_toy, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('UKMBot',
                    style: GoogleFonts.manrope(
                        fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
                Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration:
                          const BoxDecoration(color: Color(0xFF4ADE80), shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _usingGroq ? 'Groq · Llama 3.3 · Dalam Talian' : 'Mod Asas · Dalam Talian',
                      style: GoogleFonts.inter(fontSize: 11, color: Colors.white70),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Header banner
          Container(
            color: AppColors.primary,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(
                    _usingGroq ? Icons.auto_awesome : Icons.info_outline,
                    color: Colors.white70,
                    size: 14,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _usingGroq
                          ? 'Dikuasakan oleh Groq · Llama 3.3 70B · Boleh menjawab sebarang soalan'
                          : 'Mod asas aktif — tetapkan API key Groq untuk AI penuh',
                      style: GoogleFonts.inter(fontSize: 12, color: Colors.white70),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Messages list
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              itemCount: _messages.length + (_isTyping ? 1 : 0),
              itemBuilder: (ctx, i) {
                if (_isTyping && i == _messages.length) {
                  return _buildTypingIndicator();
                }
                return _buildBubble(_messages[i]);
              },
            ),
          ),

          // Quick actions
          if (_messages.length <= 2)
            Container(
              color: AppColors.surfaceContainerLow,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Topik Popular:',
                      style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.onSurfaceVariant)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _quickActions
                        .map((a) => GestureDetector(
                              onTap: () => _send(a['query']!),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceContainerLowest,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: AppColors.outlineVariant),
                                ),
                                child: Text(a['label']!,
                                    style: GoogleFonts.inter(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.primary)),
                              ),
                            ))
                        .toList(),
                  ),
                ],
              ),
            ),

          // Input bar
          SafeArea(
            top: false,
            child: Container(
              color: AppColors.surfaceContainerLowest,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: AppColors.outlineVariant),
                      ),
                      child: TextField(
                        controller: _controller,
                        decoration: InputDecoration(
                          hintText: 'Taip soalan anda...',
                          hintStyle: GoogleFonts.inter(
                              fontSize: 14, color: AppColors.onSurfaceVariant),
                          border: InputBorder.none,
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        style:
                            GoogleFonts.inter(fontSize: 14, color: AppColors.onSurface),
                        textInputAction: TextInputAction.send,
                        onSubmitted: _send,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => _send(_controller.text),
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [AppColors.primary, Color(0xFF1A56C8)],
                        ),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBubble(_ChatMessage msg) {
    final isUser = msg.isUser;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.smart_toy, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isUser ? AppColors.primary : AppColors.surfaceContainerLowest,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isUser ? 18 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 18),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                msg.text,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: isUser ? Colors.white : AppColors.onSurface,
                  height: 1.5,
                ),
              ),
            ),
          ),
          if (isUser) const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration:
                BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.smart_toy, color: Colors.white, size: 16),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
                bottomLeft: Radius.circular(4),
                bottomRight: Radius.circular(18),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (i) => _TypingDot(delay: i * 200)),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Typing animation dot ──────────────────────────────────────────────────────
class _TypingDot extends StatefulWidget {
  final int delay;
  const _TypingDot({required this.delay});
  @override
  State<_TypingDot> createState() => _TypingDotState();
}

class _TypingDotState extends State<_TypingDot> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _anim = Tween(begin: 0.0, end: -6.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _ctrl.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Transform.translate(
        offset: Offset(0, _anim.value),
        child: Container(
          width: 8,
          height: 8,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.6),
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}

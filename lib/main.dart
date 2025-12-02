import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';

void main() {
  runApp(const DirectoApp());
}

// --- TEMA KONTROLÜ ---
class ThemeController extends ValueNotifier<ThemeMode> {
  ThemeController() : super(ThemeMode.dark);

  void toggleTheme() {
    value = value == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
  }
}

final themeController = ThemeController();

// --- FORMATLAYICI ---
class TurkeyPhoneNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (text.length > 10) return oldValue;

    var buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      buffer.write(text[i]);
      var nonZeroIndex = i + 1;
      if (nonZeroIndex == 3 && nonZeroIndex != text.length) buffer.write(' ');
      if (nonZeroIndex == 6 && nonZeroIndex != text.length) buffer.write(' ');
      if (nonZeroIndex == 8 && nonZeroIndex != text.length) buffer.write(' ');
    }

    var string = buffer.toString();
    return newValue.copyWith(
      text: string,
      selection: TextSelection.collapsed(offset: string.length),
    );
  }
}

class DirectoApp extends StatelessWidget {
  const DirectoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeController,
      builder: (context, currentMode, child) {
        return MaterialApp(
          title: 'Directo',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            brightness: Brightness.light,
            primaryColor: const Color(0xFF25D366),
            scaffoldBackgroundColor: const Color(0xFFF0F2F5),
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF25D366),
            ),
            textTheme: GoogleFonts.poppinsTextTheme(),
            useMaterial3: true,
            iconTheme: const IconThemeData(color: Colors.black87),
          ),
          darkTheme: ThemeData(
            brightness: Brightness.dark,
            primaryColor: const Color(0xFF075E54),
            scaffoldBackgroundColor: const Color(0xFF111B21),
            cardColor: const Color(0xFF1F2C34),
            colorScheme: ColorScheme.dark(
              primary: const Color(0xFF00A884),
              secondary: const Color(0xFF00A884),
              surface: const Color(0xFF1F2C34),
            ),
            textTheme: GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme),
            useMaterial3: true,
            iconTheme: const IconThemeData(color: Colors.white70),
          ),
          themeMode: currentMode,
          home: const HomePage(),
        );
      },
    );
  }
}

// --- GARANTİ LOGO (DÜZELTİLDİ) ---
class DirectoLogo extends StatelessWidget {
  final double size;

  const DirectoLogo({super.key, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFF25D366), // Sabit Yeşil
        borderRadius: BorderRadius.circular(size * 0.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Icon(
        Icons.send, // En temel send ikonu
        size: size * 0.6,
        color: Colors.white, // Sabit Beyaz
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  bool _isLoading = true;
  String _selectedCountryCode = '+90';

  List<String> _history = [];
  Map<String, String> _historyNotes = {};
  List<String> _quickMessages = [];
  late AnimationController _animController;

  final List<Map<String, String>> _countryCodes = [
    {'code': '+90', 'name': 'TR 🇹🇷'},
    {'code': '+1', 'name': 'US 🇺🇸'},
    {'code': '+49', 'name': 'DE 🇩🇪'},
    {'code': '+44', 'name': 'UK 🇬🇧'},
    {'code': '+33', 'name': 'FR 🇫🇷'},
    {'code': '+994', 'name': 'AZ 🇦🇿'},
  ];

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    await _loadHistory();
    await _loadTemplates();
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) {
      setState(() => _isLoading = false);
      _animController.forward();
      _checkClipboard();
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    _phoneController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  // --- DATA ---
  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _history = prefs.getStringList('directo_history') ?? [];
      String? notesJson = prefs.getString('directo_notes');
      if (notesJson != null) {
        _historyNotes = Map<String, String>.from(json.decode(notesJson));
      }
    });
  }

  Future<void> _addToHistory(String fullNumber) async {
    if (_history.contains(fullNumber)) _history.remove(fullNumber);
    _history.insert(0, fullNumber);
    if (_history.length > 5) _history = _history.sublist(0, 5);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('directo_history', _history);
    setState(() {});
  }

  Future<void> _updateNoteForNumber(String number, String note) async {
    setState(() {
      if (note.trim().isEmpty) {
        _historyNotes.remove(number);
      } else {
        _historyNotes[number] = note.trim();
      }
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('directo_notes', json.encode(_historyNotes));
  }

  Future<void> _loadTemplates() async {
    final prefs = await SharedPreferences.getInstance();
    List<String>? saved = prefs.getStringList('directo_templates');
    if (saved == null || saved.isEmpty) {
      _quickMessages = [
        "Selam, müsait misin?",
        "Konum atabilir misin?",
        "Seni sonra arayacağım.",
      ];
    } else {
      _quickMessages = saved;
    }
    setState(() {});
  }

  Future<void> _addTemplate(String msg) async {
    if (msg.trim().isEmpty) return;
    setState(() {
      _quickMessages.add(msg.trim());
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('directo_templates', _quickMessages);
  }

  Future<void> _removeTemplate(String msg) async {
    setState(() {
      _quickMessages.remove(msg);
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('directo_templates', _quickMessages);
  }

  Future<void> _checkClipboard() async {
    try {
      ClipboardData? data = await Clipboard.getData(Clipboard.kTextPlain);
      if (data != null && data.text != null) {
        String cleanText = data.text!.replaceAll(RegExp(r'[^0-9]'), '');
        if (cleanText.length >= 10) {
          _showClipboardDialog(data.text!.trim());
        }
      }
    } catch (e) {}
  }

  String _getFormattedNumber() {
    String rawNumber = _phoneController.text.replaceAll(' ', '').trim();
    if (rawNumber.startsWith('0')) rawNumber = rawNumber.substring(1);
    return "$_selectedCountryCode$rawNumber";
  }

  Future<void> _launchWhatsApp() async {
    if (_phoneController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Önce bir numara yazmalısın!")),
      );
      return;
    }
    String fullNumber = _getFormattedNumber();
    String message = _messageController.text;
    _addToHistory(fullNumber);

    final Uri url = Uri.parse(
      "https://wa.me/$fullNumber?text=${Uri.encodeComponent(message)}",
    );
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("WhatsApp açılamadı.")));
    }
  }

  // --- POPUPS ---
  void _showClipboardDialog(String text) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Numara Yakaladım!"),
        content: Text(
          "Panonda şu numara var: $text\nBunu kullanmak ister misin?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Hayır"),
          ),
          FilledButton(
            onPressed: () {
              String raw = text.replaceAll(RegExp(r'[^0-9]'), '');
              if (raw.startsWith('0')) raw = raw.substring(1);
              _phoneController.text = raw;
              Navigator.pop(context);
            },
            child: const Text("Yapıştır"),
          ),
        ],
      ),
    );
  }

  void _showAddTemplateDialog() {
    TextEditingController tempController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Yeni Şablon"),
        content: TextField(
          controller: tempController,
          decoration: const InputDecoration(
            hintText: "Örn: IBAN: TR12...",
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("İptal"),
          ),
          FilledButton(
            onPressed: () {
              _addTemplate(tempController.text);
              Navigator.pop(context);
            },
            child: const Text("Kaydet"),
          ),
        ],
      ),
    );
  }

  void _showDeleteTemplateDialog(String msg) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Şablonu Sil"),
        content: Text("\"$msg\" silinsin mi?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Vazgeç"),
          ),
          TextButton(
            onPressed: () {
              _removeTemplate(msg);
              Navigator.pop(context);
            },
            child: const Text("Sil", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showNoteDialog(String number) {
    TextEditingController noteController = TextEditingController(
      text: _historyNotes[number] ?? "",
    );
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("İsim Ver"),
        content: TextField(
          controller: noteController,
          decoration: const InputDecoration(
            hintText: "Örn: Tesisatçı Ali",
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("İptal"),
          ),
          FilledButton(
            onPressed: () {
              _updateNoteForNumber(number, noteController.text);
              Navigator.pop(context);
            },
            child: const Text("Kaydet"),
          ),
        ],
      ),
    );
  }

  void _showLinkGeneratorDialog() {
    String currentNumber = _getFormattedNumber();
    TextEditingController linkMsgController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          String link = "https://wa.me/$currentNumber";
          if (linkMsgController.text.isNotEmpty) {
            link += "?text=${Uri.encodeComponent(linkMsgController.text)}";
          }
          return AlertDialog(
            title: const Text("Link Oluştur"),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "Bu linki kopyala, profiline yapıştır.",
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                  const SizedBox(height: 15),
                  if (_phoneController.text.isEmpty)
                    const Text(
                      "⚠️ Önce ana ekranda numara girmelisin.",
                      style: TextStyle(color: Colors.redAccent, fontSize: 12),
                    ),
                  const SizedBox(height: 5),
                  TextField(
                    controller: linkMsgController,
                    decoration: const InputDecoration(
                      labelText: "Varsayılan Mesaj (Opsiyonel)",
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (v) => setState(() {}),
                  ),
                  const SizedBox(height: 15),
                  SelectableText(
                    link,
                    style: const TextStyle(color: Colors.blue, fontSize: 13),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Kapat"),
              ),
              FilledButton.icon(
                onPressed: _phoneController.text.isEmpty
                    ? null
                    : () {
                        Clipboard.setData(ClipboardData(text: link));
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Link Kopyalandı!")),
                        );
                      },
                icon: const Icon(Icons.copy, size: 16),
                label: const Text("Kopyala"),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showQRDialog() {
    if (_phoneController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Numara girmelisin!")));
      return;
    }
    String fullNumber = _getFormattedNumber();
    String message = _messageController.text;
    String waLink =
        "https://wa.me/$fullNumber?text=${Uri.encodeComponent(message)}";

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Directo QR",
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 20),
              Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.grey.shade300, width: 2),
                ),
                padding: const EdgeInsets.all(10),
                child: Center(
                  child: QrImageView(
                    data: waLink,
                    version: QrVersions.auto,
                    size: 230.0,
                    backgroundColor: Colors.white,
                    padding: EdgeInsets.zero,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Kapat"),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showHelpSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) {
        bool isDark = Theme.of(context).brightness == Brightness.dark;
        return DefaultTabController(
          length: 2,
          child: Container(
            height: MediaQuery.of(context).size.height * 0.7,
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Container(
                  width: 50,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(height: 20),
                const TabBar(
                  tabs: [
                    Tab(text: "Kurulum"),
                    Tab(text: "Özellikler"),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      ListView(
                        children: [
                          const SizedBox(height: 20),
                          _buildInstallStep(
                            Icons.apple,
                            "iPhone (Safari)",
                            "Paylaş butonu -> Ana Ekrana Ekle",
                            isDark,
                          ),
                          _buildInstallStep(
                            Icons.android,
                            "Android (Chrome)",
                            "3 Nokta -> Uygulamayı Yükle",
                            isDark,
                          ),
                        ],
                      ),
                      ListView(
                        children: [
                          const SizedBox(height: 20),
                          _buildInfoItem(
                            Icons.qr_code,
                            "QR & Link",
                            "Numara paylaşmak için.",
                          ),
                          _buildInfoItem(
                            Icons.edit,
                            "İsim Verme",
                            "Geçmiş numaraları kaydet.",
                          ),
                          _buildInfoItem(
                            Icons.flash_on,
                            "Hızlı Mesaj",
                            "Kendi şablonlarını ekle.",
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInstallStep(
    IconData icon,
    String title,
    String desc,
    bool isDark,
  ) {
    return ListTile(
      leading: Icon(icon, size: 30, color: const Color(0xFF25D366)),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(desc),
    );
  }

  Widget _buildInfoItem(IconData icon, String title, String desc) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF25D366)),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(desc),
    );
  }

  // --- SPLASH ---
  Widget _buildSplashScreen(bool isDark) {
    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF111B21)
          : const Color(0xFFF0F2F5),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const DirectoLogo(size: 100),
            const SizedBox(height: 20),
            Text(
              "Directo",
              style: GoogleFonts.poppins(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 20),
            const CircularProgressIndicator(color: Color(0xFF25D366)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    if (_isLoading) return _buildSplashScreen(isDark);

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            DirectoLogo(size: 28),
            SizedBox(width: 10),
            Text("Directo", style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          // STACK KULLANDIK: Menü sayfanın üzerinde "Yüzer"
          child: Stack(
            children: [
              // --- 1. SAYFA İÇERİĞİ ---
              Column(
                children: [
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.only(
                        left: 20,
                        right: 20,
                        top: 20,
                        bottom: 100,
                      ), // Alt boşluk bıraktık ki menü kapatmasın
                      children: [
                        // Giriş Kartı
                        FadeTransition(
                          opacity: _animController,
                          child: Card(
                            elevation: 4,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(20.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Container(
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? Colors.black26
                                          : Colors.grey[100]!,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                          ),
                                          decoration: BoxDecoration(
                                            border: Border(
                                              right: BorderSide(
                                                color: Colors.grey.withOpacity(
                                                  0.3,
                                                ),
                                              ),
                                            ),
                                          ),
                                          child: DropdownButtonHideUnderline(
                                            child: DropdownButton<String>(
                                              value: _selectedCountryCode,
                                              dropdownColor: isDark
                                                  ? const Color(0xFF1F2C34)
                                                  : Colors.white,
                                              onChanged: (val) => setState(
                                                () =>
                                                    _selectedCountryCode = val!,
                                              ),
                                              items: _countryCodes
                                                  .map(
                                                    (c) => DropdownMenuItem(
                                                      value: c['code'],
                                                      child: Text(c['code']!),
                                                    ),
                                                  )
                                                  .toList(),
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          child: TextField(
                                            controller: _phoneController,
                                            keyboardType: TextInputType.phone,
                                            inputFormatters: [
                                              TurkeyPhoneNumberFormatter(),
                                            ],
                                            decoration: const InputDecoration(
                                              hintText: "5XX XXX XX XX",
                                              border: InputBorder.none,
                                              contentPadding:
                                                  EdgeInsets.symmetric(
                                                    horizontal: 16,
                                                  ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 15),
                                  TextField(
                                    controller: _messageController,
                                    maxLines: 3,
                                    minLines: 1,
                                    decoration: InputDecoration(
                                      labelText: "Mesajın (Opsiyonel)",
                                      filled: true,
                                      fillColor: isDark
                                          ? Colors.black26
                                          : Colors.grey[100]!,
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide.none,
                                      ),
                                      prefixIcon: const Icon(Icons.message),
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  Row(
                                    children: [
                                      Expanded(
                                        flex: 1,
                                        child: OutlinedButton(
                                          onPressed: _showQRDialog,
                                          style: OutlinedButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 16,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                          ),
                                          // İKON DEĞİŞTİ: qr_code (Standart)
                                          child: Icon(
                                            Icons.qr_code,
                                            size: 28,
                                            color: isDark
                                                ? Colors.white
                                                : Colors.black,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        flex: 3,
                                        child: ElevatedButton.icon(
                                          onPressed: _launchWhatsApp,
                                          style: ElevatedButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 16,
                                            ),
                                            backgroundColor: const Color(
                                              0xFF25D366,
                                            ),
                                            foregroundColor: Colors.white,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                          ),
                                          // İKON DEĞİŞTİ: send (Standart)
                                          icon: const Icon(Icons.send),
                                          label: const Text(
                                            "WhatsApp",
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 25),

                        // Şablonlar
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                "Hızlı Şablonlar",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey,
                                ),
                              ),
                              Text(
                                "Silmek için basılı tut",
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey.withOpacity(0.6),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            ..._quickMessages.map((msg) {
                              return GestureDetector(
                                onTap: () => setState(
                                  () => _messageController.text = msg,
                                ),
                                onLongPress: () =>
                                    _showDeleteTemplateDialog(msg),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? Colors.teal.withOpacity(0.2)
                                        : Colors.green.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: isDark
                                          ? Colors.teal
                                          : Colors.green.shade200,
                                    ),
                                  ),
                                  child: Text(
                                    msg,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: isDark
                                          ? Colors.tealAccent
                                          : Colors.green[800],
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                            GestureDetector(
                              onTap: _showAddTemplateDialog,
                              // EKLE BUTONU DÜZELTİLDİ: Arka plan rengi belirgin
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? Colors.white10
                                      : Colors.grey[300],
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: Colors.grey),
                                ),
                                child: Icon(
                                  Icons.add,
                                  size: 18,
                                  color: isDark ? Colors.white : Colors.black,
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 25),

                        // Geçmiş
                        if (_history.isNotEmpty) ...[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                "Son Aramalar",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              TextButton(
                                onPressed: () async {
                                  final prefs =
                                      await SharedPreferences.getInstance();
                                  await prefs.remove('directo_history');
                                  await prefs.remove('directo_notes');
                                  setState(() {
                                    _history.clear();
                                    _historyNotes.clear();
                                  });
                                },
                                child: const Text(
                                  "Temizle",
                                  style: TextStyle(color: Colors.redAccent),
                                ),
                              ),
                            ],
                          ),
                          ..._history.map((num) {
                            String displayName = _historyNotes[num] ?? num;
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              color: isDark
                                  ? const Color(0xFF1F2C34)
                                  : Colors.white,
                              child: ListTile(
                                leading: const Icon(
                                  Icons.history,
                                  color: Colors.grey,
                                ),
                                title: Text(
                                  displayName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                trailing: IconButton(
                                  icon: const Icon(Icons.edit, size: 18),
                                  onPressed: () => _showNoteDialog(num),
                                ),
                                onTap: () {
                                  final cleanNum = num.replaceAll(' ', '');
                                  final url = Uri.parse(
                                    "https://wa.me/$cleanNum",
                                  );
                                  launchUrl(
                                    url,
                                    mode: LaunchMode.externalApplication,
                                  );
                                },
                              ),
                            );
                          }),
                        ],
                      ],
                    ),
                  ),
                ],
              ),

              // --- 2. YÜZEN ALT MENÜ (SABİT VE GARANTİ) ---
              Positioned(
                bottom: 20,
                left: 20,
                right: 20,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 20,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF232D36)
                        : Colors.white, // Menü rengi net
                    borderRadius: BorderRadius.circular(30), // Hap şeklinde
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      // İKONLAR STANDARD (Link, Help, Brightness)
                      _buildBottomMenuItem(
                        Icons.link,
                        "Link",
                        Colors.blueAccent,
                        _showLinkGeneratorDialog,
                        isDark,
                      ),
                      Container(
                        width: 1,
                        height: 24,
                        color: Colors.grey.withOpacity(0.3),
                      ), // Ayraç
                      _buildBottomMenuItem(
                        Icons.help,
                        "Yardım",
                        const Color(0xFF25D366),
                        _showHelpSheet,
                        isDark,
                      ),
                      Container(
                        width: 1,
                        height: 24,
                        color: Colors.grey.withOpacity(0.3),
                      ), // Ayraç
                      _buildBottomMenuItem(
                        isDark ? Icons.light_mode : Icons.dark_mode,
                        "Tema",
                        Colors.amber,
                        () => themeController.toggleTheme(),
                        isDark,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomMenuItem(
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
    bool isDark,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.grey[300] : Colors.grey[800],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

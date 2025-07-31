import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:flutter_markdown/flutter_markdown.dart'; // Markdown desteği için ekleyin
import '../providers/ip_provider.dart';

class ChatBotScreen extends StatefulWidget {
  final String? drugSummary;
  final String? initialSummary; // Yeni parametre
  final String? drugName;       // Yeni parametre
  final bool isResuming;        // Yeni parametre

  const ChatBotScreen({
    Key? key,
    this.drugSummary,
    this.initialSummary,
    this.drugName,
    this.isResuming = false,
  }) : super(key: key);

  @override
  State<ChatBotScreen> createState() => _ChatBotScreenState();
}

class _ChatBotScreenState extends State<ChatBotScreen> {
  late List<Map<String, String>> messages;
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // Flutter TTS instance
  late FlutterTts flutterTts;
  bool isSpeaking = false;
  String? currentSpeakingMessage;
  bool _isLoading = false; // API yükleme durumu

  @override
  void initState() {
    super.initState();
    initTts();
    initMessages();
  }

  void initMessages() {
    String? summary = widget.initialSummary ?? widget.drugSummary;
    String drugName = widget.drugName ?? 'İlaç';

    String welcomeMessage = summary != null
        ? (widget.isResuming
        ? 'Merhaba! 👋 $drugName için güncel bilgileri hazırladım. Önceki sohbetinize devam edebilirsiniz.'
        : 'Merhaba! 👋 İlaç bilgilerinizi analiz ettim. Size nasıl yardımcı olabilirim?')
        : 'Merhaba! 👋 Maalesef bu ilaç için detaylı bilgi bulunamadı, ancak genel sorularınızda yardımcı olmaya çalışacağım.';

    messages = [
      {'role': 'bot', 'text': welcomeMessage},
    ];

    // Özet limiti kaldırıldı - TAM ÖZET GÖSTERİLİYOR
    if (summary != null) {
      messages.add({
        'role': 'bot',
        'text': '📋 İlaç Bilgileri:\n\n$summary' // Artık kısaltma yok
      });
    }
  }

  // TTS'yi başlat
  Future<void> initTts() async {
    flutterTts = FlutterTts();

    try {
      await flutterTts.setLanguage("tr-TR");
      await flutterTts.setSpeechRate(0.6);
      await flutterTts.setVolume(1.0);
      await flutterTts.setPitch(1.0);

      flutterTts.setCompletionHandler(() {
        if (mounted) {
          setState(() {
            isSpeaking = false;
            currentSpeakingMessage = null;
          });
        }
      });

      flutterTts.setErrorHandler((message) {
        if (mounted) {
          setState(() {
            isSpeaking = false;
            currentSpeakingMessage = null;
          });
        }
        debugPrint('TTS error: $message');
      });

      debugPrint('TTS initialized successfully');
    } catch (e) {
      debugPrint('TTS initialization error: $e');
    }
  }

  @override
  void dispose() {
    flutterTts.stop();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // Metni seslendir
  Future<void> speak(String text) async {
    try {
      if (isSpeaking) {
        await flutterTts.stop();
        setState(() {
          isSpeaking = false;
          currentSpeakingMessage = null;
        });
      } else {
        setState(() {
          isSpeaking = true;
          currentSpeakingMessage = text;
        });

        // Emojileri, özel karakterleri ve markdown formatını temizle
        String cleanText = text
            .replaceAll(RegExp(r'[👋🤖💊⚕️🔍📋⚠️💡🩺📄✅❌⏳]'), '')
            .replaceAll(RegExp(r'\*\*(.*?)\*\*'), r'\1') // **metin** -> metin
            .replaceAll(RegExp(r'\*(.*?)\*'), r'\1')     // *metin* -> metin
            .replaceAll(RegExp(r'"'), '')
            .replaceAll(RegExp(r'\n'), ' ')
            .trim();

        debugPrint('Speaking: $cleanText');

        var result = await flutterTts.speak(cleanText);
        if (result != 1) {
          setState(() {
            isSpeaking = false;
            currentSpeakingMessage = null;
          });
        }
      }
    } catch (e) {
      debugPrint('TTS speak error: $e');
      if (mounted) {
        setState(() {
          isSpeaking = false;
          currentSpeakingMessage = null;
        });
      }
    }
  }

  // API'ye soru-cevap isteği gönder
  Future<void> sendQuestionToAPI(String question) async {
    // initialSummary varsa onu kullan, yoksa drugSummary'yi kullan
    String? summary = widget.initialSummary ?? widget.drugSummary;

    if (summary == null) {
      setState(() {
        messages.add({
          'role': 'bot',
          'text': 'Maalesef bu ilaç için detaylı bilgi bulunamadığından kapsamlı bir cevap veremiyorum. Lütfen bir doktora danışmanızı öneririm. 🩺'
        });
        _isLoading = false;
      });
      _scrollToBottom();
      return;
    }

    final ipProvider = Provider.of<IpProvider>(context, listen: false);

    try {
      final url = Uri.parse('${ipProvider.ip}:5000/soru-cevap');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'soru': question,
          'ozet': summary,
        }),
      ).timeout(Duration(seconds: 180));

      if (mounted) {
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          setState(() {
            messages.add({
              'role': 'bot',
              'text': data['cevap'] ?? 'Cevap alınamadı.'
            });
            _isLoading = false;
          });
        } else {
          final errorData = json.decode(response.body);
          setState(() {
            messages.add({
              'role': 'bot',
              'text': 'Üzgünüm, şu anda cevabınızı bulamıyorum. Lütfen daha sonra tekrar deneyin. 😔\n\nHata: ${errorData['error'] ?? 'Bilinmeyen hata'}'
            });
            _isLoading = false;
          });
        }
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          messages.add({
            'role': 'bot',
            'text': 'Bağlantı sorunu yaşıyoruz. İnternet bağlantınızı kontrol edip tekrar deneyin. 📡'
          });
          _isLoading = false;
        });
        _scrollToBottom();
      }
      debugPrint('API error: $e');
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isLoading) return;

    setState(() {
      messages.add({'role': 'user', 'text': text});
      _isLoading = true;
    });

    _controller.clear();
    _scrollToBottom();

    await sendQuestionToAPI(text);
  }

  // Hızlı mesaj gönderme
  void _sendQuickMessage(String message) {
    if (_isLoading) return;

    _controller.text = message;
    sendMessage();
  }

  Widget buildMessage(Map<String, String> msg) {
    bool isUser = msg['role'] == 'user';
    String messageText = msg['text'] ?? '';
    bool isCurrentSpeaking = currentSpeakingMessage == messageText;
    bool isLongMessage = messageText.length > 200;

    return Container(
      margin: EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            // Bot avatar
            Container(
              margin: EdgeInsets.only(right: 8, top: 2),
              padding: EdgeInsets.all(6),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.teal.shade400, Colors.teal.shade600],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.teal.withOpacity(0.3),
                    spreadRadius: 1,
                    blurRadius: 3,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
              child: Icon(
                Icons.smart_toy_outlined,
                color: Colors.white,
                size: 20,
              ),
            ),
          ],

          // Mesaj balonu
          Flexible(
            child: Column(
              crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.75,
                  ),
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: isUser
                        ? LinearGradient(
                      colors: [Colors.blue.shade400, Colors.blue.shade600],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                        : LinearGradient(
                      colors: [Colors.grey.shade50, Colors.grey.shade100],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                      bottomLeft: isUser ? Radius.circular(16) : Radius.circular(4),
                      bottomRight: isUser ? Radius.circular(4) : Radius.circular(16),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        spreadRadius: 0,
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                    border: !isUser ? Border.all(
                      color: Colors.grey.shade200,
                      width: 1,
                    ) : null,
                  ),
                  child: !isUser
                      ? MarkdownBody(
                    data: messageText,
                    styleSheet: MarkdownStyleSheet(
                      p: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey.shade800,
                        height: 1.4,
                      ),
                      strong: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800,
                      ),
                      em: TextStyle(
                        fontSize: 15,
                        fontStyle: FontStyle.italic,
                        color: Colors.grey.shade800,
                      ),
                      h1: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800,
                      ),
                      h2: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800,
                      ),
                      h3: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    selectable: true,
                  )
                      : Text(
                    messageText,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                      height: 1.4,
                    ),
                  ),
                ),

                // Bot mesajları için ses ve zaman bilgisi
                if (!isUser) ...[
                  SizedBox(height: 6),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Ses butonu
                      Container(
                        decoration: BoxDecoration(
                          color: isCurrentSpeaking
                              ? Colors.red.shade50
                              : Colors.teal.shade50,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isCurrentSpeaking
                                ? Colors.red.shade300
                                : Colors.teal.shade300,
                            width: 1,
                          ),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () => speak(messageText),
                            child: Padding(
                              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isCurrentSpeaking ? Icons.stop : Icons.volume_up,
                                    size: 16,
                                    color: isCurrentSpeaking
                                        ? Colors.red.shade600
                                        : Colors.teal.shade600,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    isCurrentSpeaking ? 'Durdur' : 'Dinle',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: isCurrentSpeaking
                                          ? Colors.red.shade700
                                          : Colors.teal.shade700,
                                    ),
                                  ),
                                  if (isCurrentSpeaking) ...[
                                    SizedBox(width: 4),
                                    SizedBox(
                                      width: 10,
                                      height: 10,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 1.5,
                                        valueColor: AlwaysStoppedAnimation<Color>(
                                            Colors.red.shade600
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (isLongMessage) ...[
                        SizedBox(width: 8),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${(messageText.length / 100).ceil()} dk okuma',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),

          if (isUser) ...[
            // Kullanıcı avatar
            Container(
              margin: EdgeInsets.only(left: 8, top: 2),
              padding: EdgeInsets.all(6),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue.shade400, Colors.blue.shade600],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withOpacity(0.3),
                    spreadRadius: 1,
                    blurRadius: 3,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
              child: Icon(
                Icons.person_outline,
                color: Colors.white,
                size: 20,
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // initialSummary varsa onu kullan, yoksa drugSummary'yi kullan
    String? summary = widget.initialSummary ?? widget.drugSummary;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                Icons.medical_information_outlined,
                size: 22,
                color: Colors.white,
              ),
            ),
            SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'İlaç Asistanı',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        summary != null
                            ? '✅ Bilgiler mevcut'
                            : '⚠️ Sınırlı bilgi',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                      if (isSpeaking) ...[
                        SizedBox(width: 8),
                        Icon(
                          Icons.volume_up,
                          size: 14,
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: Colors.teal.shade700,
        foregroundColor: Colors.white,
        iconTheme: IconThemeData(
          color: Colors.white,
          size: 24,
        ),
        elevation: 2,
        actions: [
          if (isSpeaking)
            IconButton(
              icon: Icon(Icons.volume_off, color: Colors.white),
              onPressed: () async {
                await flutterTts.stop();
                setState(() {
                  isSpeaking = false;
                  currentSpeakingMessage = null;
                });
              },
              tooltip: 'Sesi Durdur',
            ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.teal.shade50,
              Colors.blue.shade50,
              Colors.white,
            ],
          ),
        ),
        child: Column(
          children: [
            // Durum kartı
            Container(
              margin: EdgeInsets.all(12),
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: summary != null
                      ? Colors.green.shade300
                      : Colors.orange.shade300,
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    spreadRadius: 1,
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(
                    summary != null
                        ? Icons.check_circle_outline
                        : Icons.info_outline,
                    color: summary != null
                        ? Colors.green.shade600
                        : Colors.orange.shade600,
                    size: 24,
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          summary != null
                              ? 'İlaç hakkında sorularınızı sorabilirsiniz'
                              : 'Genel bilgilendirme yapabilirim',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (summary != null) ...[
                          SizedBox(height: 2),
                          Text(
                            '🔊 Cevapları sesli dinleyebilirsiniz',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Mesajlar listesi
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: EdgeInsets.symmetric(vertical: 8),
                itemCount: messages.length + (_isLoading ? 1 : 0),
                itemBuilder: (_, i) {
                  if (i >= messages.length) {
                    // Loading indicator
                    return Container(
                      margin: EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          Container(
                            margin: EdgeInsets.only(right: 8),
                            padding: EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(
                              Icons.smart_toy_outlined,
                              color: Colors.grey.shade600,
                              size: 20,
                            ),
                          ),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(16),
                                topRight: Radius.circular(16),
                                bottomRight: Radius.circular(16),
                                bottomLeft: Radius.circular(4),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.teal.shade600
                                    ),
                                  ),
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Cevabınızı hazırlıyorum...',
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: Colors.grey.shade700,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  return buildMessage(messages[i]);
                },
              ),
            ),

            // Alt kısım - mesaj gönderme
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    spreadRadius: 0,
                    blurRadius: 8,
                    offset: Offset(0, -2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Hızlı cevap butonları - sadece summary varsa göster
                  if (summary != null) ...[
                    Container(
                      height: 50,
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          _buildQuickReplyButton('Nasıl kullanılır?', Icons.help_outline),
                          SizedBox(width: 6),
                          _buildQuickReplyButton('Doz bilgisi?', Icons.medication),
                          SizedBox(width: 6),
                          _buildQuickReplyButton('Yan etkiler?', Icons.warning_amber_outlined),
                          SizedBox(width: 6),
                          _buildQuickReplyButton('Saklama koşulları?', Icons.storage_outlined),
                        ],
                      ),
                    ),
                    Divider(height: 1, color: Colors.grey.shade200),
                  ],

                  // Mesaj input alanı
                  Container(
                    padding: EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.grey.shade300,
                                width: 1,
                              ),
                            ),
                            child: TextField(
                              controller: _controller,
                              enabled: !_isLoading,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                              ),
                              decoration: InputDecoration(
                                hintText: _isLoading
                                    ? 'Lütfen bekleyin...'
                                    : 'Sorunuzu yazın...',
                                hintStyle: TextStyle(
                                  fontSize: 15,
                                  color: Colors.grey.shade500,
                                ),
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                prefixIcon: Icon(
                                  Icons.edit_outlined,
                                  color: Colors.grey.shade500,
                                  size: 20,
                                ),
                              ),
                              onSubmitted: (_) => sendMessage(),
                              maxLines: null,
                            ),
                          ),
                        ),
                        SizedBox(width: 8),
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: _isLoading
                                  ? [Colors.grey.shade400, Colors.grey.shade500]
                                  : [Colors.teal.shade400, Colors.teal.shade600],
                            ),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: (_isLoading ? Colors.grey : Colors.teal).withOpacity(0.3),
                                spreadRadius: 0,
                                blurRadius: 4,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: IconButton(
                            icon: _isLoading
                                ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                                : Icon(
                              Icons.send,
                              color: Colors.white,
                              size: 20,
                            ),
                            onPressed: _isLoading ? null : sendMessage,
                            padding: EdgeInsets.all(10),
                          ),
                        ),
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

  Widget _buildQuickReplyButton(String text, IconData icon) {
    return GestureDetector(
      onTap: () => _sendQuickMessage(text),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: _isLoading ? Colors.grey.shade200 : Colors.teal.shade100,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _isLoading ? Colors.grey.shade300 : Colors.teal.shade300,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: _isLoading ? Colors.grey.shade500 : Colors.teal.shade700,
            ),
            SizedBox(width: 4),
            Text(
              text,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _isLoading ? Colors.grey.shade500 : Colors.teal.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
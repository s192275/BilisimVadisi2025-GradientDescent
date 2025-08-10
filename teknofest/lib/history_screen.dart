import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'chatbot_screen.dart';
import 'models/history_store.dart';
import '../providers/ip_provider.dart';

class HistoryScreen extends StatefulWidget {
  final List<Map<String, dynamic>> history;

  HistoryScreen({required this.history});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late List<Map<String, dynamic>> _localHistory;

  @override
  void initState() {
    super.initState();
    _localHistory = List.from(widget.history);
  }

  // Eski kayıt için özet yeniden çek ve sohbeti başlat
  Future<void> _resumeChat(BuildContext context, Map<String, dynamic> historyItem) async {
    final drugName = _extractDrugName(historyItem['ocr_text']);
    final first3Words = _getFirst3Words(historyItem['ocr_text'] ?? '');

    // Loading dialog göster
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                strokeWidth: 4,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.teal.shade600),
              ),
              SizedBox(height: 20),
              Text(
                'İlaç bilgileri hazırlanıyor...',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8),
              Text(
                '$drugName için özet yeniden çekiliyor',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );

    try {
      // Mevcut /ozet endpoint'ini kullan
      String? newSummary = await _fetchDrugSummaryFromAPI(first3Words);

      // Dialog'u kapat
      Navigator.of(context).pop();

      if (newSummary != null && newSummary.isNotEmpty) {
        // Başarılı - ChatBot sayfasına yönlendir
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatBotScreen(
              initialSummary: newSummary,
              drugName: drugName,
              isResuming: true, // Bu parametre ile önceki sohbet olduğunu belirt
            ),
          ),
        );

        // Başarı mesajı göster
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.refresh, color: Colors.white),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '$drugName için bilgiler güncellendi! Sohbete başlayabilirsiniz.',
                    style: TextStyle(fontSize: 15),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            margin: EdgeInsets.all(16),
            duration: Duration(seconds: 4),
          ),
        );
      } else {
        // Hata durumu - Özet çekilemedi
        _showErrorDialog(context, drugName, historyItem);
      }

    } catch (e) {
      // Dialog'u kapat
      Navigator.of(context).pop();

      // Hata durumu
      _showErrorDialog(context, drugName, historyItem);
      print('Özet çekme hatası: $e');
    }
  }

  // İlk 3 kelimeyi ayıklayan yardımcı fonksiyon
  String _getFirst3Words(String text) {
    if (text.trim().isEmpty) return '';
    final words = text.trim().split(RegExp(r'\s+'));
    final first3Words = words.take(3).toList();
    return first3Words.join(' ');
  }

  // API'den özet çek (mevcut /ozet endpoint'ini kullan)
  Future<String?> _fetchDrugSummaryFromAPI(String first3Words) async {
    if (first3Words.trim().isEmpty) {
      return null;
    }

    try {
      final ipProvider = Provider.of<IpProvider>(context, listen: false);

      // Mevcut /ozet endpoint'ini kullan
      final response = await http.post(
        Uri.parse('${ipProvider.ip}:5000/ozet'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'ilac': first3Words,
        }),
      ).timeout(Duration(seconds: 120));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['ozet'];
      } else {
        print('API Error: ${response.statusCode}');
        final errorData = jsonDecode(response.body);
        print('Error message: ${errorData['error']}');
        return null;
      }
    } catch (e) {
      print('API Hatası: $e');
      return null;
    }
  }

  // Hata dialog'u göster
  void _showErrorDialog(BuildContext context, String drugName, Map<String, dynamic> historyItem,) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.orange.shade600, size: 28),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Bilgi Alınamadı',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$drugName için güncel bilgiler alınamadı.',
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey.shade700,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Olası nedenler:',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700,
              ),
            ),
            Text(
              '• İnternet bağlantısı problemi\n• İlaç adı bulunamadı\n• Sunucu geçici olarak erişilemez',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Tamam',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.teal.shade600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Tekrar dene
              _resumeChat(context, historyItem);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal.shade600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              'Tekrar Dene',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Tek bir kaydı sil
  void _deleteItem(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.delete_outline, color: Colors.red.shade600, size: 28),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Kaydı Sil',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          'Bu ilaç kaydını silmek istediğinizden emin misiniz?',
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey.shade700,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'İptal',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              setState(() {
                _localHistory.removeAt(index);
                // Global history'den de sil
                if (index < globalHistory.length) {
                  globalHistory.removeAt(index);
                }
              });

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.white),
                      SizedBox(width: 8),
                      Text('Kayıt başarıyla silindi'),
                    ],
                  ),
                  backgroundColor: Colors.green.shade600,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  margin: EdgeInsets.all(16),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              'Sil',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Tüm kayıtları sil
  void _deleteAllItems() {
    if (_localHistory.isEmpty) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.delete_sweep, color: Colors.red.shade600, size: 28),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Tüm Kayıtları Sil',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          'Tüm ilaç kayıtlarını silmek istediğinizden emin misiniz? Bu işlem geri alınamaz.',
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey.shade700,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'İptal',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              setState(() {
                _localHistory.clear();
                globalHistory.clear();
              });

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.white),
                      SizedBox(width: 8),
                      Text('Tüm kayıtlar başarıyla silindi'),
                    ],
                  ),
                  backgroundColor: Colors.green.shade600,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  margin: EdgeInsets.all(16),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              'Tümünü Sil',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(Map<String, dynamic> item) {
    int timestamp = item['timestamp'] ?? DateTime.now().millisecondsSinceEpoch;
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return '${date.day}.${date.month}.${date.year}';
  }

  String _formatTime(Map<String, dynamic> item) {
    int timestamp = item['timestamp'] ?? DateTime.now().millisecondsSinceEpoch;
    final time = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  // OCR metninden sadece ilk kelimeyi al
  String _extractDrugName(String? ocrText) {
    if (ocrText == null || ocrText.trim().isEmpty) {
      return 'Bilinmeyen İlaç';
    }

    String firstWord = ocrText.trim().split(RegExp(r'\s+')).first;

    if (firstWord.length > 100) {
      firstWord = firstWord.substring(0, 100);
    }

    return firstWord.isNotEmpty ? firstWord : 'Bilinmeyen İlaç';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(25),
              ),
              child: Icon(
                Icons.history,
                size: 24,
                color: Colors.white,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Önceki Aramalar',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '🔄 Özet yeniden çekilir',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.9),
                    ),
                    overflow: TextOverflow.ellipsis,
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
          size: 28,
        ),
        elevation: 4,
        actions: [
          // Geçmiş kayıtlar varsa daha fazla seçenek menüsü göster
          if (_localHistory.isNotEmpty)
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, color: Colors.white),
              onSelected: (value) {
                if (value == 'delete_all') {
                  _deleteAllItems();
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'delete_all',
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.delete_sweep, color: Colors.red.shade600, size: 20),
                      SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'Tümünü Sil',
                          style: TextStyle(
                            color: Colors.red.shade600,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
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
        child: _localHistory.isEmpty
            ? _buildEmptyState()
            : Column(
          children: [
            // Üst bilgi kartı - Güncellenmiş açıklama
            Container(
              margin: EdgeInsets.all(16),
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(
                  color: Colors.blue.shade200,
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.2),
                    spreadRadius: 1,
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.refresh,
                    color: Colors.blue.shade600,
                    size: 28,
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Önceki ilaçlarınız için güncel bilgiler çekilecek',
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Tıkladığınız ilaç için özet yeniden hazırlanır',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Kayıt sayısı
            Container(
              margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Icon(
                    Icons.inventory,
                    color: Colors.grey.shade600,
                    size: 20,
                  ),
                  SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      '${_localHistory.length} adet kayıt bulundu',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

            // Geçmiş listesi
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.symmetric(horizontal: 16),
                itemCount: _localHistory.length,
                itemBuilder: (_, i) {
                  final item = _localHistory[i];
                  final drugName = _extractDrugName(item['ocr_text']);
                  final first3Words = _getFirst3Words(item['ocr_text'] ?? '');

                  return Container(
                    margin: EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.3),
                          spreadRadius: 1,
                          blurRadius: 6,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                    child: ListTile(
                      contentPadding: EdgeInsets.all(16),
                      leading: Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(
                            color: Colors.grey.shade300,
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.2),
                              spreadRadius: 1,
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(13),
                          child: Image.file(
                            File(item['path']),
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: Colors.grey.shade200,
                                child: Icon(
                                  Icons.medication,
                                  color: Colors.grey.shade500,
                                  size: 32,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      title: Text(
                        drugName,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade800,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(height: 8),

                          // OCR metninin bir kısmını göster
                          if (item['ocr_text'] != null && item['ocr_text'].toString().trim().isNotEmpty)
                            Container(
                              margin: EdgeInsets.only(bottom: 8),
                              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.blue.shade200,
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                item['ocr_text'].toString().length > 50
                                    ? '${item['ocr_text'].toString().substring(0, 50)}...'
                                    : item['ocr_text'].toString(),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.blue.shade700,
                                  fontStyle: FontStyle.italic,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),

                          // API'ye gönderilecek veri önizleme
                          if (first3Words.isNotEmpty)
                            Container(
                              margin: EdgeInsets.only(bottom: 8),
                              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.green.shade200,
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                'API\'ye gönderilecek: "$first3Words"',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.green.shade700,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),

                          // Tarih ve saat satırı
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                Icon(
                                  Icons.calendar_today,
                                  size: 16,
                                  color: Colors.grey.shade500,
                                ),
                                SizedBox(width: 6),
                                Text(
                                  _formatDate(item),
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey.shade600,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                SizedBox(width: 16),
                                Icon(
                                  Icons.access_time,
                                  size: 16,
                                  color: Colors.grey.shade500,
                                ),
                                SizedBox(width: 6),
                                Text(
                                  _formatTime(item),
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey.shade600,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: 8),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade100,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.orange.shade300,
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.refresh,
                                  size: 14,
                                  color: Colors.orange.shade700,
                                ),
                                SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    'Özet yeniden çekilecek',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.orange.shade700,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      trailing: SizedBox(
                        width: 80,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            // Sil butonu
                            GestureDetector(
                              onTap: () => _deleteItem(i),
                              child: Container(
                                padding: EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade100,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  Icons.delete_outline,
                                  color: Colors.red.shade600,
                                  size: 18,
                                ),
                              ),
                            ),
                            SizedBox(width: 6),
                            // İlerle butonu
                            Container(
                              padding: EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.teal.shade100,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.arrow_forward_ios,
                                color: Colors.teal.shade700,
                                size: 18,
                              ),
                            ),
                          ],
                        ),
                      ),
                      onTap: () => _resumeChat(context, item),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
  //Boş durum
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(50),
                border: Border.all(
                  color: Colors.grey.shade300,
                  width: 2,
                ),
              ),
              child: Icon(
                Icons.history_toggle_off,
                size: 64,
                color: Colors.grey.shade500,
              ),
            ),
            SizedBox(height: 24),
            Text(
              '📭 Henüz Kayıt Yok',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 12),
            Text(
              'Henüz hiç ilaç fotoğrafı yüklememişsiniz.\nİlk fotoğrafınızı yükleyerek başlayın!',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 32),
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.8),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(
                  color: Colors.teal.shade200,
                  width: 2,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.lightbulb_outline,
                    color: Colors.orange.shade600,
                    size: 24,
                  ),
                  SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      'Ana sayfadan fotoğraf yükleyerek başlayabilirsiniz',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
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
}
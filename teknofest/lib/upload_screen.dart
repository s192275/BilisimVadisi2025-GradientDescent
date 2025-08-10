import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'chatbot_screen.dart';
import 'models/history_store.dart';
import 'widgets/upload_dialogs.dart';
import '../providers/ip_provider.dart';

class UploadScreen extends StatefulWidget {
  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  File? _image;
  bool _isUploading = false;
  bool _isProcessingOCR = false;
  String? _extractedText;
  bool _showOCRResults = false;
  final TextEditingController _ocrController = TextEditingController();

  // API'den gelen özet için değişkenler
  String? _drugSummary;
  bool _isLoadingAPIData = false;
  String? _apiError;
  bool _apiRequestCompleted = false; // API isteğinin tamamlanıp tamamlanmadığını takip eder

  // Gönder butonunun aktif olup olmadığını kontrol eden getter
  bool get _canSend {
    final text = _ocrController.text.trim();
    return text.isNotEmpty && _image != null && !_isUploading && !_isProcessingOCR && !_isLoadingAPIData;
  }

  Future<bool> requestPermission(Permission permission) async {
    final status = await permission.status;
    
    // İzine göre true dön ya da tekrar iste
    if (status.isGranted) return true;

    if (status.isDenied) {
      final result = await permission.request();
      return result.isGranted;
    }

    // İzin kalıcı olarak reddedilmişse ayarlara yönlendir
    if (status.isPermanentlyDenied) {
      Fluttertoast.showToast(msg: 'İzin ayarlardan verilmelidir.');
      openAppSettings();
      return false;
    }

    return false;
  }

  // Kamera ya da galeriden resim
  Future<void> pickImage(ImageSource source) async {
    bool granted = await requestPermission(
      source == ImageSource.camera
          ? Permission.camera
          : (Platform.isAndroid ? Permission.photos : Permission.storage),
    );

    if (!granted) return;
    
    // Resim seç
    final picked = await ImagePicker().pickImage(source: source);
    if (picked != null) {
      // Yeni resim seçildiğinde önceki durumları temizle
      setState(() {
        _image = File(picked.path);
        _showOCRResults = false;
        _extractedText = null;
        _ocrController.clear();
        _drugSummary = null;
        _apiError = null;
        _apiRequestCompleted = false;
      });

      // OCR işlemini başlat
      await _performOCR();
    }
  }

  // OCR
  Future<void> _performOCR() async {
    if (_image == null) return;

    setState(() {
      _isProcessingOCR = true;
    });

    try {
      // Resmi ML Kit için uygun formata çevir
      final inputImage = InputImage.fromFile(_image!);
      final textRecognizer = TextRecognizer();
      final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);

      // Tanınan metinleri birleştir
      String extractedText = '';
      for (TextBlock block in recognizedText.blocks) {
        for (TextLine line in block.lines) {
          extractedText += '${line.text}\n';
        }
      }

      // Sonuçları UI'da göster
      setState(() {
        _extractedText = extractedText.trim();
        _ocrController.text = _extractedText ?? '';
        _showOCRResults = true;
        _isProcessingOCR = false;
      });
      
      // Kaynakları temizle
      await textRecognizer.close();

      // Hiç metin yoksa uyar
      if (_extractedText?.isEmpty ?? true) {
        UploadDialogs.showNoTextDialog(context);
      }
    } catch (e) {
      setState(() {
        _isProcessingOCR = false;
      });

      Fluttertoast.showToast(
        msg: 'Metin tanıma hatası: $e',
        toastLength: Toast.LENGTH_LONG,
      );
    }
  }
  
  // Tekrar resmi al
  void _retakePhoto() {
    setState(() {
      _image = null;
      _extractedText = null;
      _showOCRResults = false;
      _ocrController.clear();
      _drugSummary = null;
      _apiError = null;
      _apiRequestCompleted = false;
    });
  }

  // İlk 3 kelimeyi ayıklayan yardımcı fonksiyon
  String _getFirst3Words(String text) {
    final words = text.trim().split(RegExp(r'\s+'));
    final first3Words = words.take(3).toList();
    return first3Words.join(' ');
  }

  // API'ye ilaç prospektüs özeti isteği gönderen fonksiyon
  Future<void> _fetchDrugSummaryFromAPI() async {
    if (_ocrController.text.trim().isEmpty) return;

    final ipProvider = Provider.of<IpProvider>(context, listen: false);
    final first3Words = _getFirst3Words(_ocrController.text);
    
    setState(() {
      _isLoadingAPIData = true;
      _apiError = null;
      _apiRequestCompleted = false;
    });

    // ozet endpointine bağlan
    try {
      final url = Uri.parse('${ipProvider.ip}:5000/ozet');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'ilac': first3Words, // Burada hala ilk 3 kelime gönderiliyor
        }),
      ).timeout(Duration(seconds: 180));  // Timeout 90 saniye olarak değiştirildi

      setState(() {
        _isLoadingAPIData = false;
        _apiRequestCompleted = true;
      });

      // Response 200 döndüğünde formatı json'a göre ayarla
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _drugSummary = data['ozet'];
        });

        // Başarılı mesaj göster
        Fluttertoast.showToast(
          msg: 'İlaç bilgileri başarıyla alındı! ✅',
          backgroundColor: Colors.green.shade600,
          textColor: Colors.white,
        );
      } else {
        final errorData = json.decode(response.body);
        setState(() {
          _apiError = errorData['error'] ?? 'Bilinmeyen hata';
        });

        Fluttertoast.showToast(
          msg: 'İlaç bilgileri alınamadı! ❌',
          backgroundColor: Colors.red.shade600,
          textColor: Colors.white,
        );
      }
    } catch (e) {
      setState(() {
        _apiError = 'Bağlantı hatası: ${e.toString()}';
        _isLoadingAPIData = false;
        _apiRequestCompleted = true;
      });

      Fluttertoast.showToast(
        msg: 'API bağlantı hatası! ❌',
        backgroundColor: Colors.red.shade600,
        textColor: Colors.white,
        toastLength: Toast.LENGTH_LONG,
      );
    }
  }

  Future<void> fakeUpload() async {
    if (_image == null) return;

    // Metin kontrolü - eğer boşsa uyarı göster
    if (_ocrController.text.trim().isEmpty) {
      UploadDialogs.showEmptyTextWarning(context);
      return;
    }

    setState(() => _isUploading = true);

    // API'ye özet isteği gönder
    await _fetchDrugSummaryFromAPI();

    // Simüle etmek için kısa bekleme
    await Future.delayed(Duration(seconds: 2));

    final dir = await getTemporaryDirectory();
    final fileName = Uuid().v4();
    final newPath = '${dir.path}/$fileName.jpg';
    await _image!.copy(newPath);

    // OCR metnini kontrol et ve kaydet
    final extractedTextToSave = _ocrController.text.trim();
    final first3Words = _getFirst3Words(extractedTextToSave);

    // OCR metni uzunluk kontrolü (maksimum 100 karakter için ilaç adı)
    String displayName = 'Bilinmeyen İlaç';
    if (extractedTextToSave.isNotEmpty) {
      // Artık hiçbir limit yok, tam metin kullanılıyor
      displayName = extractedTextToSave;
    }

    // Global history'e ekle - API özetini de dahil et
    globalHistory.add({
      'path': newPath,
      'name': displayName,
      'ocr_text': extractedTextToSave,
      'first_3_words': first3Words,
      'drug_summary': _drugSummary, // API'den gelen özet
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });

    setState(() => _isUploading = false);

    Fluttertoast.showToast(msg: 'Fotoğraf ve metin gönderildi! 📤');
  }

  // Soru Sor butonuna basıldığında chatbot sayfasına git
  void _navigateToChatBot() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ChatBotScreen(
          drugSummary: _drugSummary, // Özeti ChatBot'a aktar
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Yeni Fotoğraf Yükle',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.teal.shade700,
        foregroundColor: Colors.white,
        iconTheme: IconThemeData(
          color: Colors.white,
          size: 28,
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.teal.shade50,
              Colors.blue.shade50,
              Colors.green.shade50,
            ],
          ),
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.all(24),
          child: Column(
            children: [
              // Başlık kartı
              _buildHeaderCard(),

              // Fotoğraf önizleme ve OCR sonuçları
              if (_image != null) ...[
                _buildImagePreview(),
                if (_isProcessingOCR) _buildOCRProcessingWidget(),
                if (_showOCRResults && !_isProcessingOCR) _buildOCRResultsWidget(),

                // API durum kartı (sadece API isteği tamamlandıysa göster)
                if (_apiRequestCompleted) _buildAPIStatusCard(),

                _buildActionButtons(),
              ],

              // Kamera ve Galeri butonları (fotoğraf seçilmediğinde)
              if (_image == null) ...[
                _buildCameraButton(),
                _buildGalleryButton(),
                _buildHelpCard(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: 30),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.3),
            spreadRadius: 2,
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(
            Icons.add_a_photo,
            size: 48,
            color: Colors.teal.shade700,
          ),
          SizedBox(height: 10),
          Text(
            '📸 İlaç Fotoğrafı Yükleyin',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.teal.shade800,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 8),
          Text(
            'İlaç kutusunun fotoğrafını çekin, metinler otomatik okunacak',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildImagePreview() {
    return Container(
      margin: EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.4),
            spreadRadius: 3,
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Image.file(
          _image!,
          height: 250,
          width: double.infinity,
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  Widget _buildOCRProcessingWidget() {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: 20),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.blue.shade100,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: Colors.blue.shade300,
          width: 2,
        ),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 30,
            width: 30,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade700),
            ),
          ),
          SizedBox(height: 12),
          Text(
            '🔍 Metinler Okunuyor...',
            style: TextStyle(
              fontSize: 18,
              color: Colors.blue.shade800,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Lütfen bekleyin, ilaç kutusundaki yazılar tanınıyor',
            style: TextStyle(
              fontSize: 14,
              color: Colors.blue.shade700,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildAPIStatusCard() {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: 20),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: _drugSummary != null
              ? Colors.green.shade300
              : Colors.red.shade300,
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _drugSummary != null ? Icons.check_circle : Icons.error,
                color: _drugSummary != null
                    ? Colors.green.shade700
                    : Colors.red.shade700,
                size: 24,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  _drugSummary != null
                      ? '✅ İlaç Bilgileri Başarıyla Alındı'
                      : '❌ İlaç Bilgileri Alınamadı',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _drugSummary != null
                        ? Colors.green.shade800
                        : Colors.red.shade800,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12),

          if (_drugSummary != null) ...[
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Colors.green.shade700,
                    size: 20,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'İlaç hakkında detaylı bilgi alınmıştır. Soru sormak için "Soru Sor" butonuna basın.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _navigateToChatBot,
                icon: Icon(Icons.chat, size: 20),
                label: Text(
                  'Soru Sor',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade600,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 4,
                ),
              ),
            ),
          ] else if (_apiError != null) ...[
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.warning_amber,
                        color: Colors.red.shade700,
                        size: 20,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'İlaç bilgileri alınamadı',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.red.shade800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 6),
                  Text(
                    _apiError!,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.red.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (_ocrController.text.isNotEmpty) ...[
            SizedBox(height: 12),
            Text(
              'API\'ye gönderilen: "${_getFirst3Words(_ocrController.text)}"',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOCRResultsWidget() {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: 20),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: Colors.green.shade300,
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.text_fields,
                color: Colors.green.shade700,
                size: 24,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  '📝 Okunan Metinler',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade800,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          _buildTextPreview(),
          Text(
            'Aşağıdaki metinler kontrol edin ve gerekirse düzenleyin:',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
          SizedBox(height: 16),
          _buildTextEditField(),
          if (_ocrController.text.trim().isEmpty) _buildTextRequiredWarning(),
        ],
      ),
    );
  }

  Widget _buildTextPreview() {
    if (_ocrController.text.trim().isNotEmpty) {
      return Container(
        width: double.infinity,
        padding: EdgeInsets.all(12),
        margin: EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.teal.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: Colors.teal.shade200,
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '📄 Okunan Metin Önizleme:',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.teal.shade700,
              ),
            ),
            SizedBox(height: 6),
            Text(
              _ocrController.text.length > 100
                  ? '${_ocrController.text.substring(0, 100)}...'
                  : _ocrController.text,
              style: TextStyle(
                fontSize: 14,
                color: Colors.teal.shade800,
              ),
            ),
          ],
        ),
      );
    } else {
      return Container(
        width: double.infinity,
        padding: EdgeInsets.all(12),
        margin: EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: Colors.orange.shade200,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.warning_amber,
              color: Colors.orange.shade600,
              size: 20,
            ),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Metin bulunamadı. Lütfen manuel olarak yazın.',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.orange.shade700,
                ),
              ),
            ),
          ],
        ),
      );
    }
  }
  
  Widget _buildTextEditField() {
    return TextField(
      controller: _ocrController,
      maxLines: 6,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w500,
      ),
      onChanged: (value) {
        setState(() {});
      },
      decoration: InputDecoration(
        hintText: 'İlaç adını veya kutusundaki metinleri buraya yazın...',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300, width: 2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.green.shade500, width: 2),
        ),
        errorBorder: _ocrController.text.trim().isEmpty
            ? OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.red.shade400, width: 2),
        )
            : null,
        filled: true,
        fillColor: Colors.grey.shade50,
        contentPadding: EdgeInsets.all(16),
      ),
    );
  }

  Widget _buildTextRequiredWarning() {
    return Container(
      margin: EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            color: Colors.red.shade500,
            size: 16,
          ),
          SizedBox(width: 6),
          Expanded(
            child: Text(
              'Göndermek için metin gereklidir',
              style: TextStyle(
                fontSize: 12,
                color: Colors.red.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        // Tekrar Fotoğraf Çek
        Expanded(
          child: Container(
            margin: EdgeInsets.only(right: 8),
            child: ElevatedButton.icon(
              icon: Icon(
                Icons.camera_alt,
                size: 24,
                color: Colors.white,
              ),
              label: Text(
                'Yeniden Çek',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange.shade600,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                elevation: 4,
              ),
              onPressed: _retakePhoto,
            ),
          ),
        ),

        // Gönder
        Expanded(
          child: Container(
            margin: EdgeInsets.only(left: 8),
            child: ElevatedButton.icon(
              icon: _isUploading || _isLoadingAPIData
                  ? SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
                  : Icon(
                Icons.send,
                size: 24,
                color: Colors.white,
              ),
              label: Text(
                _isUploading || _isLoadingAPIData ? 'Gönderiliyor...' : 'Gönder',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _canSend
                    ? Colors.green.shade600
                    : Colors.grey.shade400,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                elevation: _canSend ? 4 : 1,
              ),
              onPressed: _canSend ? fakeUpload : null,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCameraButton() {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: 20),
      child: ElevatedButton.icon(
        icon: Icon(
          Icons.camera_alt,
          size: 32,
          color: Colors.white,
        ),
        label: Text(
          'Kamera ile Fotoğraf Çek',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue.shade600,
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(horizontal: 40, vertical: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 8,
          shadowColor: Colors.blue.withOpacity(0.4),
        ),
        onPressed: () => pickImage(ImageSource.camera),
      ),
    );
  }

  Widget _buildGalleryButton() {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: 30),
      child: ElevatedButton.icon(
        icon: Icon(
          Icons.photo_library,
          size: 32,
          color: Colors.white,
        ),
        label: Text(
          'Galeriden Seç',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.purple.shade600,
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(horizontal: 40, vertical: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 8,
          shadowColor: Colors.purple.withOpacity(0.4),
        ),
        onPressed: () => pickImage(ImageSource.gallery),
      ),
    );
  }

  Widget _buildHelpCard() {
    return Container(
      margin: EdgeInsets.only(top: 30),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.8),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: Colors.orange.shade200,
          width: 2,
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.lightbulb_outline,
            color: Colors.orange.shade700,
            size: 32,
          ),
          SizedBox(height: 10),
          Text(
            '💡 İpucu',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.orange.shade800,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'En iyi sonuç için ilaç kutusunun etiketini net, iyi ışıklı ve düz bir açıdan çekin.',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _ocrController.dispose();
    super.dispose();
  }
}
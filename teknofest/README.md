# İlaç Asistanı - Mobil Uygulama

Flutter ile geliştirilmiş, kullanıcıların ilaçları hakkında AI destekli sorular sorabileceği akıllı sağlık asistanı uygulaması.

## 🚀 Özellikler

- **İlaç Tanıma**: Kamera ile ilaç kutularını tarayarak bilgi alma
- **AI Chatbot**: İlaçlar hakkında doğal dilde soru-cevap
- **Sesli Asistan**: Cevapları Türkçe sesli dinleme
- **Markdown Desteği**: Kalın, italik metin formatları
- **Hızlı Sorular**: Yaygın sorular için hazır butonlar
- **Modern UI**: Gradient tasarım ve smooth animasyonlar

## 📱 Ekranlar

- **Ana Sayfa**: İlaç tarama ve geçmiş sohbetler
- **Kamera**: İlaç kutusu tanıma ve analiz
- **ChatBot**: AI asistan ile sohbet
- **Sonuçlar**: İlaç bilgileri ve detaylar

## 🛠️ Teknolojiler

- **Flutter 3.** - Cross-platform framework
- **Provider** - State management
- **HTTP** - API iletişimi
- **Flutter TTS** - Sesli okuma
- **Camera** - Kamera işlemleri
- **Image Picker** - Resim seçme
- **Flutter Markdown** - Metin formatlama
- **Speech To Text** - Konuşmanın metne dönüştürülmesi

## 📋 Kurulum

### Gereksinimler
- Flutter 3.0+
- Dart 3.0+
- Android Studio / VS Code
- Android SDK 21+ / iOS 11+

### Adımlar
```bash
# Projeyi klonla
git clone https://github.com/s192275/BilisimVadisi2025-GradientDescent.git

# Bağımlılıkları yükle
flutter pub get

# Python tarafındaki bağımlılıkları yükle (app.py'ın bulunduğu sayfaya geçip)
pip install -r requirements.txt

# Uygulamayı çalıştır
flutter run
```

## ⚙️ Yapılandırma

```dart
String _ip = 'http://YOUR_SERVER_IP';
```

### Kamera İzinleri
- **Android**: `android/app/src/main/AndroidManifest.xml`
- **iOS**: `ios/Runner/Info.plist`

## 📝 Önemli Notlar

- Backend server çalışır durumda olmalı
- İnternet bağlantısı gerekli
- Kamera izinleri verilmeli
- Android 6.0+ için runtime permissions

## 🚀 Build & Deploy

### Android APK
```bash
flutter build apk --release
```

### iOS
```bash
flutter build ios --release
```

## 🤝 Katkıda Bulunma

1. Fork yapın
2. Feature branch oluşturun (`git checkout -b feature/amazing-feature`)
3. Commit yapın (`git commit -m 'Add amazing feature'`)
4. Push yapın (`git push origin feature/amazing-feature`)
5. Pull Request açın

## 📄 Lisans

Bu proje APACHE lisansı altında lisanslanmıştır.

## 📞 İletişim

Proje ile ilgili sorularınız için issue açabilirsiniz.

---

**Not**: Bu uygulama sadece bilgilendirme amaçlıdır. Tıbbi kararlar için mutlaka doktorunuza danışın.

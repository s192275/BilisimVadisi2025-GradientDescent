

# Teknofest 2025 Doğal Dil İşleme Yarışması  
## **GradientDescent Ekibi: Yaşlı Dostu İlaç Prospektüsü Sistemi**

---

### **Projenin Vizyonu**

GradientDescent ekibi olarak, **Teknofest 2025 Doğal Dil İşleme Yarışması Serbest Kategori** kapsamında geliştirdiğimiz bu proje, yaşlı bireylerin ilaç prospektüslerini kolayca anlamalarını ve sağlık bilgilerine erişimlerini artırmayı amaçlıyor. Görme, dijital okuryazarlık veya bilişsel zorluklar nedeniyle prospektüsleri anlamakta güçlük çeken bireyler için **kullanıcı dostu, sesli destekli ve erişilebilir** bir sistem tasarladık. Amacımız, yaşlı bireylerin **ilaç güvenliğini artırmak**, yanlış kullanımları önlemek ve **bağımsızlıklarını desteklemek**!

---

### **Sistem Nasıl Çalışıyor?**

Sistem, yaşlı bireylerin ihtiyaçlarına özel olarak tasarlanmış, sezgisel ve etkileşimli bir süreç sunar:

1. **📷 Fotoğraf Yükleme**: Kullanıcı, ilaç kutusunun veya prospektüsün fotoğrafını Streamlit arayüzüne kolayca yükler.
2. **🔍 Optik Karakter Tanıma (OCR)**: EasyOCR ile görseldeki metin hızlıca çıkarılır.
3. **🌐 Web’den Bilgi Toplama**: PyDuckDuckGo ile ilaca dair güncel ve güvenilir bilgiler toplanır.
4. **📝 Prospektüs Özeti**: Intelligent-Internet/II-Medical8B-1706 modeli, prospektüsü sade, anlaşılır ve yaşlı dostu bir şekilde özetler.
5. **🎤 Sesli Soru-Cevap**: Kullanıcı, ilaca dair sorularını sesli sorar. SpeechRecognition ve Whisper ile sorular metne çevrilir, model tarafından yanıtlanır ve gTTS ile sesli olarak kullanıcıya sunulur.
6. **🔊 Tamamen Sesli Etkileşim**: Dokunmatik ekran veya okuma gerektirmeden, sesli komutlarla sistem kolayca kullanılır.

---

### **Kullanılan Teknolojiler**

- **EasyOCR**: Görselden metin çıkarma için hızlı ve doğru çözüm.
- **PyDuckDuckGo**: Güvenilir web verileri toplama.
- **Intelligent-Internet/II-Medical8B-1706**: Prospektüs özetleme ve akıllı soru-cevap.
- **gTTS**: Yazıyı doğal ses çıkışına dönüştürme.
- **SpeechRecognition & Whisper**: Sesli girdileri metne çevirme.
- **Streamlit**: Kullanıcı dostu ve modern web arayüzü.

Sistem, **Hugging Face token** ve **GOOGLE_API_KEY** ile entegre bir şekilde Streamlit platformunda çalışmaktadır.

---

### **Gelecekteki Yenilikler**

Projemiz, mevcut haliyle güçlü bir temel sunuyor ve ilerleyen süreçlerde daha da gelişecek:

- **📱 Mobil Uygulama Geliştirme**: Sistem testleri tamamlandıktan sonra, kullanıcı dostu bir mobil uygulama tasarlanacak ve uygulama mağazalarında yerini alacak.
- **🧠 Gelişmiş NLP Özetleme**: Mobil uygulamada, ilaç prospektüslerinin özetlenmesi için ileri düzey doğal dil işleme (NLP) teknikleri kullanılacak.
- **🚫 İlaç Dışı İçerik Kısıtlamaları**: İlaç dışı görsellerin yüklenmesini engelleyen filtreleme mekanizmaları eklenecek.
- **🎯 Özel Başlık Erişimi**: Kullanıcılar, **yan etkiler**, **kullanım talimatları** veya **kontrendikasyonlar** gibi belirli başlıkları doğrudan görüntüleyip dinleyebilecek.
- **📚 Büyük Dil Modeli İnce Ayar**: Kullanıcıların sorularına cevap verebilmesi için mobilde çalışabilecek küçük model eğitimleri yapılacaktır.

---

### **İnsanlığa Katkılar**

#### **Toplumsal Faydalar**
- **👴 Yaşlı Dostu Tasarım**: Görme veya okuma güçlüğü çeken bireyler için erişilebilir bir deneyim.
- **🛡️ İlaç Güvenliği**: Yanlış kullanım riskini azaltır, ilaç etkileşimleri hakkında bilgi sunar.
- **🌟 Bağımsızlık**: Yaşlı bireylerin eczane veya bakıcılara bağımlılığı azalır.
- **📚 Sağlık Okuryazarlığı**: Karmaşık prospektüsleri sadeleştirerek bilgiye erişimi kolaylaştırır.

#### **Etkileşim ve İş Birlikleri**
- **👨‍👩‍👧 Aileler ve Bakıcılar**: Yaşlı bireylerin sağlık sorularına hızlı yanıtlarla güven sağlar.
- **🏥 Sağlık Kuruluşları**: Evde bakım sistemlerine entegre edilebilir bir çözüm.
- **💊 Eczaneler**: Reçetesiz ilaçlar için dijital danışmanlık aracı olarak kullanılabilir.

---

### **Neden GradientDescent?**

GradientDescent ekibi olarak, teknolojinin insan hayatını kolaylaştırması gerektiğine inanıyoruz. Yaşlı bireylerin sağlık hizmetlerine erişimdeki zorluklarını çözmek için **insan odaklı, yenilikçi ve erişilebilir** bir sistem geliştirdik. Teknofest 2025’te bu vizyonu hayata geçirerek, **yaşlı dostu teknolojilerle sağlık okuryazarlığını güçlendirmeyi** ve topluma değer katmayı hedefliyoruz!

**GradientDescent ile sağlık bilgisi herkes için erişilebilir!**


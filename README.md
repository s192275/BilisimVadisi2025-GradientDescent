Bu Streamlit arayüzü Teknofest 2025 Doğal Dil İşleme yarışması kapsamında Serbest Kategori altında GradientDescent ekibi tarafından geliştirilmiştir.

**1. Oluşturulan Sistemin Amacı**

Bu projenin temel amacı, yaşlı bireylerin ilaç prospektüslerini daha kolay ve etkili bir şekilde anlayabilmelerini sağlamaktır. Göz sağlığı, dijital okuryazarlık düzeyi ve bilişsel nedenlerle ilaç içeriklerini okumakta veya anlamakta zorlanan bireyler için bir mobil destek sistemi geliştirilmesi planlanmıştır. Sistem; kullanıcıdan alınan ilaç görselini analiz ederek içeriğini okur, prospektüsü anlamlı bir şekilde özetler ve bireyin sesli sorularını anlayıp yanıtlar. Böylece yaşlı bireylerin ilaçlar hakkında bilinçli karar vermeleri, yanlış kullanımın önlenmesi ve bağımsızlıklarının artırılması hedeflenmiştir.

**2. İşleyiş**

Sistem aşağıdaki adımlarla çalışır:

**1.Fotoğraf Yükleme:** Kullanıcı, ilaç kutusunun veya prospektüsün fotoğrafını sisteme yükler.

**2.Optik Karakter Tanıma (OCR):** Yüklenen görsel EasyOCR kütüphanesi ile işlenir ve metin çıkarımı yapılır.

**3.Web Üzerinden Bilgi Toplama:** Çıkarılan metin üzerinden DuckDuckGo arama motoru kullanılarak ilaca dair güncel ve doğru bilgiler toplanır.

**4.Prospektüs Özeti:** Intelligent-Internet/II-Medical8B-1706 adlı büyük dil modeli kullanılarak prospektüsün sade ve anlaşılır bir özeti oluşturulur.

**5.Soru-Cevap Modülü:** Kullanıcı ilaca dair sesli sorular yöneltir. Soru önce speech-to-text modülü ile yazıya çevrilir, ardından dil modeli soruyu yanıtlar ve yanıt text-to-speech ile sesli şekilde kullanıcıya sunulur.

**6.Sesli Etkileşim:** Girdiler ve çıktılar sesli desteklidir, böylece yaşlı bireyler dokunmadan veya okuma zorunluluğu olmadan sistemi kullanabilir.

**3. Kullanılan Teknolojiler**

EasyOCR

PyDuckDuckGo

Intelligent-Internet/II-Medical8B-1706

gTTS 

SpeechRecognition, Whisper

Streamlit

4. İnsanlığa Yararları ve Etkileşimler

**Toplumsal Faydalar:**

Yaşlı Dostu Tasarım: Görme ve okuma güçlüğü çeken bireyler için erişilebilirlik sağlar.

İlaç Güvenliği: Yanlış ilaç kullanımı riskini azaltır, ilaç etkileşimleri konusunda bilgi verir.

Bağımsızlık: Bireylerin eczaneye ya da aile üyelerine bağlı kalmadan bilgiye ulaşmalarını sağlar.

Sağlık Okuryazarlığı: Prospektüsler sadeleştirilerek bireylerin ilacı daha iyi anlamaları sağlanır.

**Etkileşim:**

Aileler & Bakıcılar: Yaşlı bireylerin sağlıkla ilgili sorularına daha hızlı yanıt almasını sağlayarak onlara güven verir.

Sağlık Kuruluşları: Evde bakım sistemlerine entegre edilebilir.

Eczaneler: Reçete dışı ilaçlar için danışmanlık hizmetlerinin dijital uzantısı olabilir.


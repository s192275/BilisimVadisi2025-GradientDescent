from flask import Flask, request, jsonify # Serverın temel kısmı ve isteklerle veri paketini oluşturan kısımlar
from ddgs import DDGS # Aramalar için
import requests # Gelen istekler için
from bs4 import BeautifulSoup # Veri çekmek için
from huggingface_hub import InferenceClient # Modeli lokal bilgisayara kurmadan çekebilmek için
import os # API key'deki environmentı çekmek için
from dotenv import load_dotenv # .env dosyasını sisteme dahil etmek için
import re # regex işlemleri için
import itertools # iterasyon

# .env dosyasını yükle
load_dotenv()
# Flask uygulamasını oluştur
app = Flask(__name__)

# Global değişken yerine dictionary kullan
prospektus_cache = {}

def get_prospektus(ilac_adi:str) -> str:
    """
    Mobil uygulamadan test edilen ilaç adını ve mg cinsini birleştirerek DuckDuckGo üzerinde arama yapar ve sitelerdeki içeriklerden uygun olanı döner.
    Bu fonksiyonda 2 yaklaşımız var. İlk yaklaşım dönen sorguları tek tek modele atıp sonucun prospektüsle alakalı olup olmadığını bularak ilk uygun prospektüs içeriğini dönmek.
    İkinci yaklaşımsa Türkiye genelinde bir çok ilaç prospektüsünü içeren siteleri sorgulayıp oradaki içeriği dönmek.
    
    Args:
        ilac_adi (str): Araştırılması istenilen ilaç adı

    Returns:
        str: Prospektüs içeriği
    """
    query = f"{ilac_adi} prospektüsü"
    with DDGS() as ddgs:
        results =list(itertools.islice(ddgs.text(query, region="wt-wt", safesearch="moderate"),5))
        
    if not results:
        return None
    #İlk yaklaşım
    #for result in results:
        #url = result.get('href')
        #try:
            #resp = requests.get(url, timeout=30, headers={'User-Agent': 'Mozilla/5.0'})
            #soup = BeautifulSoup(resp.text, 'html.parser')

            # Gereksiz elementleri kaldır
            #for element in soup(["script", "style", "nav", "header", "footer"]):
                #element.decompose()

            #body = soup.find('body')
            #full_text = body.get_text(separator='\n', strip=True) if body else soup.get_text(separator='\n', strip=True)
            #if len(full_text) > 50000:
                #full_text = full_text[:50000] + "..."

            # HuggingFace ile içerik kontrolü
            #kontrol = question_with_hf(full_text)
            #if "none" in kontrol.lower():
                #continue  # Prospektüs değilse sonraki URL'ye geç
            #else:
                #return full_text
        #except Exception as e:
            #app.logger.warning(f"{url} alınamadı: {e}")
            #continue
    
    # İkinci yaklaşım (Bu yaklaşım çok daha hızlı olduğu için bu tercih edildi.)
    for result in results:
        href = result.get('href', '')
        if "ilacprospektusu.com/ilac/" in href or "medikalakademi.com.tr" in href or "ilacrehberi.com" in href or "ilacabak.com" in href:
            url = href
            try:
                resp = requests.get(url, timeout=30, headers={'User-Agent': 'Mozilla/5.0'})
                soup = BeautifulSoup(resp.text, 'html.parser')

                # Gereksiz elementleri kaldır
                for element in soup(["script", "style", "nav", "header", "footer"]):
                    element.decompose()

                body = soup.find('body')
                full_text = body.get_text(separator='\n', strip=True) if body else soup.get_text(separator='\n', strip=True)
                if len(full_text) > 50000:
                    full_text = full_text[:50000] + "..."

                return full_text
            except Exception as e:
                app.logger.warning(f"{url} alınamadı: {e}")
                continue
    return None

def summarize_with_hf(text:str, max_length:int=None) -> str:
    """
    Kendisine gönderilen ilaç içeriğinin özetini çıkarır. Bu işlemi bir Qwen3 temelli model olan Intelligent-Internet/II-Medical-8B-1706 ile yapar.
    
    Args:
        text (str): Özeti çıkarılacak prospektüs içeriği
        max_length (int, optional): Maksimum uzunluk

    Returns:
        str: Prospektüs özeti
    """
    client = InferenceClient(provider="featherless-ai", api_key=os.environ["HF_TOKEN"])
    
    # Metin çok uzunsa parçala
    if max_length and len(text) > max_length:
        text = text[:max_length] + "..."
    
    prompt = f"{text} bu mesajı medikal içeriğine uygun ve yaşlıların da anlayacağı şekilde kısaca özetle. Paragraf yap. Madde başlığı olmasın."
    
    try:
        response = client.chat.completions.create(
            model="Intelligent-Internet/II-Medical-8B-1706",
            messages=[{"role": "user", "content": prompt}],
            max_tokens=2048,  # Token limiti ekle
            temperature=0.7
        )
        raw = response.choices[0].message.content
        m = re.search(r"</think>\s*(.*)", raw, re.DOTALL)
        return m.group(1).strip() if m else raw
  
    except Exception as e:
        app.logger.warning(f"Özetleme hatası: {e}")
        return "Özetleme işlemi başarısız oldu."

@app.route("/ozet", methods=["POST"])
def prospektus_ozet() -> dict:
    """
    Metin özetini mobil uygulamanın beklediği json formatına çevirir ve haberleşmeyi sağlar.

    Returns:
        dict: Metin özeti, Metin uzunluğu ve özet uzunluğunu içeren bir dictionary
    """
    data = request.json
    ilac_adi = data.get("ilac")
    if not ilac_adi:
        return jsonify({"error": "İlaç adı gerekli"}), 400

    try:
        # Prospektüs metnini al
        metin = get_prospektus(ilac_adi)
        if not metin:
            return jsonify({"error": "Prospektüs bulunamadı"}), 404

        # Cache'e kaydet
        prospektus_cache[ilac_adi] = metin
        
        # Özet oluştur
        ozet = summarize_with_hf(metin, max_length=10000)  # 10K karakter limit
        
        return jsonify({
            "ozet": ozet,
            "metin_uzunlugu": len(metin),
            "ozet_uzunlugu": len(ozet)
        })
    except Exception as e:
        app.logger.warning(f"Özet endpoint hatası: {e}")
        return jsonify({"error": f"İşlem başarısız: {str(e)}"}), 500

@app.route("/soru-cevap", methods=["POST"])
def soru_cevap() -> dict:
    """
    Tam metne göre soru cevap işlemini mobil uygulamanın beklediği json formatına çevirir ve haberleşmeyi sağlar.

    Returns:
        dict: Cevap ve kullanılan metin uzunluğunu içeren bir dictionary
    """
    data = request.json
    soru = data.get("soru")
    ozet = data.get("ozet")
    ilac_adi = data.get("ilac_adi", "")  # İlaç adını da gönder

    if not soru or not ozet:
        return jsonify({"error": "Soru ve özet gerekli"}), 400

    try:
        # Cache'den tam metni al
        tam_metin = prospektus_cache.get(ilac_adi, "")
        
        # Eğer cache'de yoksa özeti kullan
        if not tam_metin:
            tam_metin = ozet
        
        client = InferenceClient(provider="featherless-ai", api_key=os.environ["HF_TOKEN"])
        prompt = f"""
            Aşağıda bir ilaç prospektüsünün tam metni verilmiştir.
            Sadece bu metne dayalı soruları cevapla.
            Eğer soru bu metinle ilgili değilse, şu şekilde yanıtla: "Bu sorunun cevabı mevcut prospektüs içinde bulunmamaktadır."

            Prospektüs Metni:
            \"\"\"{tam_metin[:15000]}\"\"\"

            Soru: {soru}
        """
        
        response = client.chat.completions.create(
            model="Intelligent-Internet/II-Medical-8B-1706",
            messages=[{"role": "user", "content": prompt}],
            max_tokens=1024,
            temperature=0.7
        )
        
        msg = response.choices[0].message.content
        m = re.search(r"</think>\s*(.*)", msg, re.DOTALL)
        cevap = m.group(1).strip() if m else msg
        
        return jsonify({
            "cevap": cevap,
            "kullanilan_metin_uzunlugu": len(tam_metin)
        })
    except Exception as e:
        app.logger.warning(f"Soru-cevap endpoint hatası: {e}")
        return jsonify({"error": f"Cevap oluşturulamadı: {str(e)}"}), 500

# Cache temizleme endpoint'i (isteğe bağlı)
@app.route("/cache-temizle", methods=["POST"])
def cache_temizle() -> dict:
    """
    Cache'i temizler.

    Returns:
        dict: Mesaj tutan bir dictionary
    """
    prospektus_cache.clear()
    return jsonify({"mesaj": "Cache temizlendi"})

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=True)

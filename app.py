from flask import Flask, request, jsonify
from ddgs import DDGS
import requests
from bs4 import BeautifulSoup
from huggingface_hub import InferenceClient
import os
from dotenv import load_dotenv
import re
import base64
import io
import itertools

load_dotenv()
app = Flask(__name__)

# Global değişken yerine dictionary kullan
prospektus_cache = {}

def get_prospektus(ilac_adi):
    query = f"{ilac_adi} prospektüsü"
    with DDGS() as ddgs:
        gen = ddgs.text(query, region="wt-wt", safesearch="moderate")
        results = list(itertools.islice(gen, 5))
    
    if not results:
        return None
    
    url = results[0].get('href')
    try:
        # Timeout artırıldı
        resp = requests.get(url, timeout=30, headers={'User-Agent': 'Mozilla/5.0'})
        soup = BeautifulSoup(resp.text, 'html.parser')
        
        # Gereksiz elementleri kaldır
        for element in soup(["script", "style", "nav", "header", "footer"]):
            element.decompose()
        
        body = soup.find('body')
        full_text = body.get_text(separator='\n', strip=True) if body else soup.get_text(separator='\n', strip=True)
        
        # Çok uzun metinleri sınırla (isteğe bağlı)
        if len(full_text) > 50000:  # 50K karakter limiti
            full_text = full_text[:50000] + "..."
        
        return full_text
    except Exception as e:
        print(f"Prospektüs alma hatası: {e}")
        return None

def summarize_with_hf(text, max_length=None):
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
        print(f"Özetleme hatası: {e}")
        return "Özetleme işlemi başarısız oldu."

@app.route("/ozet", methods=["POST"])
def prospektus_ozet():
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
        print(f"Özet endpoint hatası: {e}")
        return jsonify({"error": f"İşlem başarısız: {str(e)}"}), 500

@app.route("/soru-cevap", methods=["POST"])
def soru_cevap():
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
        print(f"Soru-cevap endpoint hatası: {e}")
        return jsonify({"error": f"Cevap oluşturulamadı: {str(e)}"}), 500

# Cache temizleme endpoint'i (isteğe bağlı)
@app.route("/cache-temizle", methods=["POST"])
def cache_temizle():
    prospektus_cache.clear()
    return jsonify({"mesaj": "Cache temizlendi"})

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=True)

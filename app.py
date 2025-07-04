import streamlit as st
import easyocr
from PIL import Image
from duckduckgo_search import DDGS
import requests
from bs4 import BeautifulSoup
from google import genai
from dotenv import load_dotenv
import os
import io
import base64
from gtts import gTTS
from huggingface_hub import InferenceClient
import re
# Soru cevaba chunk size ekleyelim. Modelin cevaplama hızı artar.

load_dotenv()

def get_response_with_medical_model(text):
    client = InferenceClient(
        provider="featherless-ai",
        api_key=os.environ["HF_TOKEN"],
    )

    completion = client.chat.completions.create(
        model="Intelligent-Internet/II-Medical-8B-1706",
        messages=[
            {
                "role": "user",
                "content": f"{text} bu mesajı medikal içeriğine uygun ve yaşlıların da anlayacağı şekilde kısaca özetle.Bütün metni paragraf yap. Madde başlıkları kullanma. Sadece özeti yaz."
        }
    ],
)

    msg = completion.choices[0].message
    content = msg.content
    m2 = re.search(r"</think>\s*(.*)", content, re.DOTALL)
    result = m2.group(1).strip()
    return result

def vocaliaze_text(text):
    try:
        tts = gTTS(text=text, lang='tr')
        speech_bytes = io.BytesIO()
        tts.write_to_fp(speech_bytes)
        speech_bytes.seek(0)
        audio_base64 = base64.b64encode(speech_bytes.read()).decode('utf-8')
        return audio_base64
    except Exception as e:
        st.error(f"Seslendirme hatası: {e}")
        return None

def summarize_text(text):
    client = genai.Client(api_key=os.getenv("GOOGLE_API_KEY"))
    response = client.models.generate_content(
        model="gemini-2.5-flash",
        contents=f"{text} Bu metni yaşlıların da anlayabileceği şekilde medikal içeriğine uygun bir şekilde kısaca özetle. Bütün metni paragraf yap. Madde başlıkları kullanma. Sadece özeti yaz.",
    )
    return response.text

def duckduckgo_search(arama_metni, max_sonuc=5):
    with DDGS() as ddgs:
        results = list(ddgs.text(keywords=arama_metni, region='wt-wt', safesearch='moderate', max_results=max_sonuc))
    if not results:
        return None

    ilk = results[0]
    url = ilk.get('href')

    try:
        resp = requests.get(url, timeout=10, headers={'User-Agent': 'Mozilla/5.0'})
        resp.raise_for_status()
        content_type = resp.headers.get('Content-Type', '').lower()

        if 'text/html' in content_type:
            soup = BeautifulSoup(resp.text, 'html.parser')
            body = soup.find('body')
            metin = body.get_text(separator='\n', strip=True) if body else soup.get_text(separator='\n', strip=True)
            return metin
        else:
            return None
    except:
        return None

def cevapla_soru(soru, ozet_metni):
    client = genai.Client(api_key=os.getenv("GOOGLE_API_KEY"))
    prompt = f"""
    Aşağıda bir ilaç prospektüsünün özeti verilmiştir.
    Sadece bu metne dayalı soruları cevapla.
    Eğer soru bu metinle ilgili değilse, şu şekilde yanıtla: "Bu sorunun cevabı mevcut prospektüs içinde bulunmamaktadır."

    Prospektüs Özeti:
    \"\"\"{ozet_metni}\"\"\"

    Soru: {soru}
    """
    yanit = client.models.generate_content(
        model="gemini-2.5-flash",
        contents=prompt
    )
    return yanit.text

def qa_with_medical_model(text, ozet_metni):
    client = InferenceClient(
        provider="featherless-ai",
        api_key=os.environ["HF_TOKEN"],
    )
    prompt = f"""
        Aşağıda bir ilaç prospektüsünün özeti verilmiştir.
        Sadece bu metne dayalı soruları cevapla.
        Eğer soru bu metinle ilgili değilse, şu şekilde yanıtla: "Bu sorunun cevabı mevcut prospektüs içinde bulunmamaktadır."

        Prospektüs Özeti:
            \"\"\"{ozet_metni}\"\"\"

        Soru: {soru}
    """
   
    completion = client.chat.completions.create(
        model="Intelligent-Internet/II-Medical-8B-1706",
        messages=[
            {
                "role": "user",
                "content": f"{prompt} "
            }
        ],
    )

    msg = completion.choices[0].message
    content = msg.content
    m2 = re.search(r"</think>\s*(.*)", content, re.DOTALL)
    result = m2.group(1).strip()
    return result

# Streamlit Arayüzü
st.title("Medikal Prospektüs Özetleme ve Soru Cevaplama Uygulaması")
st.write("Bu uygulama, medikal prospektüsleri özetler, seslendirir ve özetle ilgili soruları cevaplar.")

uploaded_file = st.file_uploader("Lütfen bir resim yükleyin", type=["jpg", "jpeg", "png"])
if uploaded_file:
    image = Image.open(uploaded_file)
    st.image(image, caption="Yüklenen Resim", use_column_width=True)
    
    reader = easyocr.Reader(['tr', 'en'], gpu=False)
    results = reader.readtext(image, detail=0)
    
    ilac = ' '.join(results[0:2])
    st.write(f"Sisteme yüklenen ilaç: {ilac}")
    
    prospektus = duckduckgo_search(f"{ilac} prospektüsü", max_sonuc=5)
    if prospektus:
        #summarized_text = summarize_text(prospektus)
        summarized_text = get_response_with_medical_model(prospektus)
        st.write(f"**Prospektüs Özeti:**\n{summarized_text}")
        
        # Sesli oynatma
        audio_base64 = vocaliaze_text(summarized_text)
        if audio_base64:
            audio_html = f'''
            <audio controls autoplay>
                <source src="data:audio/mp3;base64,{audio_base64}" type="audio/mp3">
                Tarayıcınız audio etiketini desteklemiyor.
            </audio>
            '''
            st.markdown(audio_html, unsafe_allow_html=True)

        # Soru-cevap modülü
        st.markdown("---")
        st.subheader("Prospektüse Dayalı Soru-Cevap")
        soru = st.text_input("Prospektüse göre bir soru sorun:")
        if soru:
            #cevap = cevapla_soru(soru, summarized_text)
            cevap = qa_with_medical_model(soru, summarized_text)
            st.markdown("**Cevap:**")
            st.write(cevap)
    else:
        st.warning("Prospektüs bulunamadı. Lütfen farklı bir resim deneyin.")

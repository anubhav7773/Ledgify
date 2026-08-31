from google import genai
from app.core.config import settings

client = genai.Client(api_key=settings.GEMINI_API_KEY)
models_to_test = ["gemini-2.5-flash", "gemini-3.6-flash", "gemini-3.7-flash", "gemini-flash-latest", "gemini-2.5-pro"]

for m in models_to_test:
    try:
        res = client.models.generate_content(model=m, contents="Hello, return JSON: {\"status\": \"ok\"}")
        print(f"SUCCESS with {m}: {res.text}")
    except Exception as e:
        print(f"FAILED with {m}: {e}")

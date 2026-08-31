from google import genai
from app.core.config import settings
from PIL import Image
import io

client = genai.Client(api_key=settings.GEMINI_API_KEY)

with open("C:/Users/kshtr/.gemini/antigravity-ide/brain/afada999-003e-43aa-be24-866bcc5ff37e/.user_uploaded/media_1788186132015.png", "rb") as f:
    img_bytes = f.read()

image = Image.open(io.BytesIO(img_bytes))

models_to_test = [
    "gemini-3.5-flash",
    "gemini-3.1-flash-image-preview",
    "gemini-3.1-flash-image",
    "gemini-3-pro-image-preview",
    "gemini-2.5-flash-image",
    "gemini-3.5-flash-lite",
]

prompt = (
    "Extract the seller name, invoice number, and total amount from this invoice image. Return in JSON: {\"vendor_name\": \"...\", \"invoice_number\": \"...\", \"total_amount\": 0.0}"
)

for m in models_to_test:
    try:
        res = client.models.generate_content(
            model=m,
            contents=[image, prompt]
        )
        print(f"SUCCESS with {m}: {res.text}")
    except Exception as e:
        print(f"FAILED with {m}: {e}")

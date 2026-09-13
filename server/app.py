from flask import Flask, request, jsonify
import os
from PIL import Image
import io
import pytesseract
import shutil

# Ensure pytesseract knows where the Tesseract binary is.
# Try system PATH first, then common install location on Windows.
try:
    tpath = shutil.which('tesseract') or r"C:\Program Files\Tesseract-OCR\tesseract.exe"
    if tpath and os.path.exists(tpath):
        pytesseract.pytesseract.tesseract_cmd = tpath
    else:
        # leave as default; server will return helpful error if OCR called without binary
        pytesseract.pytesseract.tesseract_cmd = tpath
except Exception:
    pass

LOG_PATH = os.path.join(os.path.dirname(__file__),'signals.log')

app = Flask(__name__)

@app.route('/')
def index():
    return jsonify({"status":"ok","service":"msnr-signal-server"})

@app.route('/signal', methods=['POST'])
def signal():
    data = request.json or {}
    # log incoming signal
    try:
        with open(LOG_PATH,'a',encoding='utf-8') as f:
            f.write(str(data) + "\n")
    except Exception as e:
        return jsonify({"received": False, "error": str(e)}),500
    return jsonify({"received": True, "data": data})


@app.route('/ocr-signal', methods=['POST'])
def ocr_signal():
    # Accepts form-data with an image file under 'image'
    if 'image' not in request.files:
        return jsonify({"error":"no image uploaded"}),400
    f = request.files['image']
    try:
        img = Image.open(io.BytesIO(f.read()))
        text = pytesseract.image_to_string(img)
        # naive parsing: look for BUY or SELL and price-like numbers
        signal = None
        if 'BUY' in text.upper(): signal = 'BUY'
        if 'SELL' in text.upper(): signal = 'SELL'
        # extract first number as price
        import re
        m = re.search(r"\d+\.?\d*", text)
        price = m.group(0) if m else None
        result = {"text": text, "signal": signal, "price": price}
        with open(LOG_PATH,'a',encoding='utf-8') as flog:
            flog.write("OCR:" + str(result) + "\n")
        return jsonify(result)
    except Exception as e:
        return jsonify({"error":str(e)}),500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8000)

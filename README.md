# MSNR BOT

Scaffolding for MT5 Expert Advisor (EA) and Android signal app.

Folders:
- `ea/` - MQL5 Expert Advisor source
- `server/` - Signal API and webhook server
- `android/` - Android app source

This repo is scaffolded by GitHub Copilot (assistant).

Quick start (server/backtest):

1. Create a Python virtualenv and install requirements:

```bash
python -m venv venv
venv\Scripts\activate
pip install -r server/requirements.txt
```

2. Run the signal server locally:

```bash
python server/app.py
```

3. Run the backtest (provide historical CSV with columns: datetime,open,high,low,close,volume):

```bash
python server/backtest.py data/historical.csv
```

Demo backtest with provided sample data:

```bash
python server/backtest.py server/example_data.csv
```

Android build (Kotlin):

- Open the `android/` folder in Android Studio and build or run the `app` module.
- To produce an APK from command line (Android Studio recommended):

```bash
# from android/ directory
./gradlew assembleDebug
```

Notes:
- The EA (`ea/msnr_scalper.mq5`) is a scaffold for MSNR-like S/R + MA scalping. It must be backtested thoroughly before live use.
- I cannot push to your Git remote or deploy to Render with your credentials; see below for push instructions.

Recommended environment setup (most reliable on Windows):

1) Install Tesseract OCR (binary)
- Download and run the UB‑Mannheim Tesseract installer: https://github.com/UB-Mannheim/tesseract/wiki
- Or run as Admin in PowerShell: `choco install tesseract -y` (requires Chocolatey and elevation). After install verify with `tesseract --version`.

2) Use Conda to install Python dependencies (avoids Windows build toolchain issues):

```powershell
# Install Miniconda from https://docs.conda.io/en/latest/miniconda.html if you don't have it
conda create -n msnr python=3.11 -y
conda activate msnr
conda install -c conda-forge pandas pillow pytesseract flask gunicorn -y
```

3) Run server and backtest:

```powershell
# activate your conda env
conda activate msnr
python server/backtest.py server/example_data.csv
python server/app.py
```

Notes about OCR:
- `pytesseract` requires the Tesseract executable. The server will attempt to detect the binary automatically. If Tesseract is installed in a non-standard location, update `server/app.py` to set `pytesseract.pytesseract.tesseract_cmd` to the full path.

Git push (local):

```bash
git init
git add .
git commit -m "Add MSNR bot scaffold"
# add your remote and push
git remote add origin <your-remote-url>
git push -u origin main
```

Render deployment (server):

1. Create a new Render web service, connect your Git repo, and set the build command to:

```bash
pip install -r server/requirements.txt
gunicorn server.app:app
```

2. Set the start command to run `gunicorn server.app:app --bind 0.0.0.0:$PORT`.
3. Add environment variables as needed (secrets, credentials).

OCR endpoint:

- POST an image file to `/ocr-signal` as form-data with key `image` to extract text and detect `BUY`/`SELL` signals.

Security & safety:

- The EA and server are samples and require thorough backtesting and risk controls before using live.


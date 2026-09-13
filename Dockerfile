FROM python:3.11-slim

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      tesseract-ocr \
      libtesseract-dev \
      libleptonica-dev \
      pkg-config \
      build-essential \
      curl && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

# copy only requirements first for faster rebuilds
COPY server/requirements.txt /app/server/requirements.txt
RUN pip install --no-cache-dir -r /app/server/requirements.txt

# copy repository
COPY . /app

ENV PYTHONUNBUFFERED=1
EXPOSE 8000

CMD ["gunicorn", "server.app:app", "--bind", "0.0.0.0:8000", "--workers", "2"]

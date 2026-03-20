FROM python:3.12-slim

WORKDIR /app

# Dependências de sistema para Ultralytics/OpenCV
RUN apt-get update && apt-get install -y \
    libgl1-mesa-glx \
    libglib2.0-0 \
    git \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Fix do CLIP para SAM-3 (ver: https://docs.ultralytics.com/pt/models/sam-3/)
RUN pip uninstall clip -y 2>/dev/null || true && \
    pip install git+https://github.com/ultralytics/CLIP.git

COPY src/ ./src/

ENV PYTHONUNBUFFERED=1
ENV PORT=8081
ENV SAM3_MODEL_PATH=/app/src/sam3.pt

EXPOSE 8081

CMD ["python", "src/server.py"]

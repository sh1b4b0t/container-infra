FROM python:3.12-slim

WORKDIR /app

# Dependências de sistema para Ultralytics/OpenCV
RUN apt-get update && apt-get install -y \
    libgl1-mesa-glx \
    libglib2.0-0 \
    git \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Instalar uv
RUN curl -LsSf https://astral.sh/uv/install.sh | sh
ENV PATH="/root/.local/bin:$PATH"

# Instalar dependências Python via lockfile (build reprodutível)
COPY pyproject.toml uv.lock ./
RUN uv sync --no-dev --no-install-project --frozen

# Fix do CLIP para SAM-3 (https://docs.ultralytics.com/pt/models/sam-3/)
RUN .venv/bin/pip uninstall clip -y 2>/dev/null || true && \
    .venv/bin/pip install git+https://github.com/ultralytics/CLIP.git

# Copiar apenas código-fonte (*.pt excluídos via .dockerignore)
COPY src/ ./src/

ENV PYTHONUNBUFFERED=1
ENV PORT=8081
ENV SAM3_MODEL_PATH=/models/sam3.pt

EXPOSE 8081

CMD [".venv/bin/python", "src/server.py"]

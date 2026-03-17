FROM python:3.12-slim

WORKDIR /app

# Install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy source code
COPY src/ ./src/

# Create data directory
RUN mkdir -p /app/data

ENV PYTHONUNBUFFERED=1
ENV TOKEN_FILE=/app/data/token.json
ENV PORT=8080

EXPOSE 8080

CMD ["python", "src/server.py"]

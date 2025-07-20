FROM python:3.11-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

RUN python -c "from sentence_transformers import SentenceTransformer; SentenceTransformer('all-MiniLM-L6-v2')"

COPY main.py .
COPY config.ini .
COPY recommendations.db .

EXPOSE 8000

# --- ADDED: Define default environment variables ---
# These will be used if they are not overridden in the `docker run` command.
ENV WORKERS=2
ENV LOG_LEVEL=info

HEALTHCHECK --interval=30s --timeout=10s --retries=3 \
  CMD curl --fail http://localhost:8000/manifest.json || exit 1

# --- CHANGED: The CMD line now uses the environment variables ---
# Note: We use the shell form (without []) to allow shell variable substitution.
CMD gunicorn -w $WORKERS -k uvicorn.workers.UvicornWorker main:app --bind 0.0.0.0:8000 --log-level $LOG_LEVEL

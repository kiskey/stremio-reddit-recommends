# ===================================================================
# STAGE 1: The "Builder" - Our temporary workshop
# ===================================================================
FROM python:3.11-slim as builder

ENV PIP_NO_CACHE_DIR=1

WORKDIR /app

# Install dependencies. This stage will have all build tools and executables.
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Download and cache the AI model.
RUN python -c "from sentence_transformers import SentenceTransformer; SentenceTransformer('all-MiniLM-L6-v2')"


# ===================================================================
# STAGE 2: The "Final" - Our slim, clean shipping crate
# ===================================================================
FROM python:3.11-slim

WORKDIR /app

# Copy the installed Python packages (the libraries) from the 'builder' stage.
COPY --from=builder /usr/local/lib/python3.11/site-packages /usr/local/lib/python3.11/site-packages

# --- THE FIX IS HERE ---
# Copy the installed executables (like gunicorn) from the 'builder' stage.
COPY --from=builder /usr/local/bin /usr/local/bin

# Copy the cached AI model from the 'builder' stage.
COPY --from=builder /root/.cache/huggingface /root/.cache/huggingface

# Copy our application code and the database.
COPY main.py .
COPY config.ini .
COPY recommendations.db .

# Set environment variables for the final image.
ENV HF_HOME=/root/.cache/huggingface
ENV SENTENCE_TRANSFORMERS_HOME=/root/.cache/huggingface
ENV WORKERS=2
ENV LOG_LEVEL=info

EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=10s --retries=3 \
  CMD curl --fail http://localhost:8000/manifest.json || exit 1

# The CMD line will now find gunicorn successfully.
CMD gunicorn -w $WORKERS -k uvicorn.workers.UvicornWorker main:app --bind 0.0.0.0:8000 --log-level $LOG_LEVEL

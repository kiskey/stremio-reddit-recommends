# ===================================================================
# STAGE 1: The "Builder" - Our temporary workshop
# ===================================================================
FROM python:3.11-slim as builder

# Set an environment variable to prevent caching pip downloads,
# as we won't need them in the final stage anyway.
ENV PIP_NO_CACHE_DIR=1

WORKDIR /app

# Install dependencies. This stage will be large.
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Download and cache the AI model. The model will be stored in /root/.cache/huggingface
RUN python -c "from sentence_transformers import SentenceTransformer; SentenceTransformer('all-MiniLM-L6-v2')"


# ===================================================================
# STAGE 2: The "Final" - Our truly slim shipping crate
# ===================================================================
FROM python:3.11-slim

WORKDIR /app

# --- The Magic Step ---
# Copy ONLY the installed packages from the 'builder' stage's site-packages.
# This brings over the pure Python code without the build cache.
COPY --from=builder /usr/local/lib/python3.11/site-packages /usr/local/lib/python3.11/site-packages

# --- The SURGICAL COPY Step ---
# Copy ONLY the huggingface model cache from the 'builder' stage.
# This leaves behind the massive pip cache.
COPY --from=builder /root/.cache/huggingface /root/.cache/huggingface

# Copy our application code and the database. These are small.
COPY main.py .
COPY config.ini .
COPY recommendations.db .

# --- Set environment variables for the final image ---
# Setting the cache home tells sentence-transformers where to find the model we just copied.
ENV HF_HOME=/root/.cache/huggingface
ENV SENTENCE_TRANSFORMERS_HOME=/root/.cache/huggingface
ENV WORKERS=2
ENV LOG_LEVEL=info

EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=10s --retries=3 \
  CMD curl --fail http://localhost:8000/manifest.json || exit 1

# The CMD line remains the same
CMD gunicorn -w $WORKERS -k uvicorn.workers.UvicornWorker main:app --bind 0.0.0.0:8000 --log-level $LOG_LEVEL

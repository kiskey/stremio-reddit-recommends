# Use an official Python runtime as a parent image
FROM python:3.11-slim

# Set the working directory in the container
WORKDIR /app

# Copy the requirements file into the container at /app
COPY requirements.txt .

# Install any needed packages specified in requirements.txt
RUN pip install --no-cache-dir -r requirements.txt

# --- Pre-cache the SentenceTransformer model ---
# This command runs during the build process, so the model is
# included in the final image layer, avoiding a download on every startup.
RUN python -c "from sentence_transformers import SentenceTransformer; SentenceTransformer('all-MiniLM-L6-v2')"

# Copy the addon code and the pre-built database into the container at /app
COPY main.py .
COPY config.ini .
COPY recommendations.db .

# Make port 8000 available to the world outside this container
EXPOSE 8000

# Define a health check
HEALTHCHECK --interval=30s --timeout=10s --retries=3 \
  CMD curl --fail http://localhost:8000/manifest.json || exit 1

# Run main.py when the container launches using a production-ready server
CMD ["gunicorn", "-w", "2", "-k", "uvicorn.workers.UvicornWorker", "main:app", "--bind", "0.0.0.0:8000"]

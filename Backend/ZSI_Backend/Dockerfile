# WildID API server for Google Cloud Run (CPU).
#
# Before building, put the trained weights in models/ (they are not in git):
#   models/zsi_wildlife_model.pth            required
#   models/ensemble/model_*_v3.pth           optional, enables /predict-ensemble
FROM python:3.11-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1

WORKDIR /app

COPY requirements-server.txt .
RUN pip install -r requirements-server.txt

# Only what the server needs (see .dockerignore for what is left out).
COPY api.py api_extended.py ensemble_predictor.py sms_service.py otp_tokens.py \
     zsi_class_mapping.json ./
COPY models/ ./models/

RUN useradd --create-home --uid 10001 app && chown -R app /app
USER app

# Cloud Run sets PORT (8080 by default). One worker keeps a single copy of the
# model in memory; threads handle concurrent requests.
ENV PORT=8080
CMD exec gunicorn --bind ":${PORT}" --workers 1 --threads 4 --timeout 60 api_extended:app

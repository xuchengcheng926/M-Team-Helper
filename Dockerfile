# ============================================================
# Stage 1: Build frontend
# ============================================================
FROM node:20-alpine AS frontend-builder

WORKDIR /build/frontend

# Install dependencies first (better layer caching)
COPY frontend/package.json frontend/package-lock.json ./
RUN npm ci --prefer-offline

# Copy source and build
COPY frontend/ ./
RUN npm run build

# ============================================================
# Stage 2: Runtime image
# ============================================================
FROM python:3.11-slim

# System dependencies
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        tzdata \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Install Python dependencies (layer cached separately from app code)
COPY backend/requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

# Copy backend source
COPY backend/ ./backend/

# Copy built frontend from stage 1
COPY --from=frontend-builder /build/frontend/dist ./frontend/dist/

# Data directory (mounted from host via volume)
RUN mkdir -p /app/data/torrents

EXPOSE 8001

ENV MTEAM_DATA_DIR=/app/data \
    DEBUG=False \
    MTEAM_BASE_URL=https://api.m-team.cc

WORKDIR /app/backend

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8001"]

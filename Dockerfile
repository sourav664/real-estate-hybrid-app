# ====================
# Builder stage
# ====================
FROM python:3.12-slim-bookworm AS builder

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential gcc && \
    rm -rf /var/lib/apt/lists/*

COPY requirements-docker.txt .

RUN pip install --prefix=/install --no-cache-dir --prefer-binary -r requirements-docker.txt

RUN apt-get purge -y build-essential gcc && apt-get autoremove -y


# =====================
# Final stage
# =====================
FROM python:3.12-slim-bookworm AS final

WORKDIR /app

# Runtime dependencies (LightGBM, etc.)
RUN apt-get update && apt-get install -y --no-install-recommends \
    libgomp1 \
    && rm -rf /var/lib/apt/lists/*

# Create audit directory for volume mount
RUN mkdir -p /app/audit && chmod -R 777 /app/audit

# Copy installed Python packages
COPY --from=builder /install /usr/local

# Copy application files
COPY ./my_app/ ./my_app/
COPY ./models/ ./models/
COPY ./run_information.json .

# Optional: data file (only if truly needed)
COPY ./data/raw/real_estate.csv ./data/raw/real_estate.csv

# Create non-root user
RUN useradd -m appuser
USER appuser

ENV PORT=8000
EXPOSE 8000

CMD ["sh", "-c", "streamlit run my_app/home.py --server.port=$PORT --server.address=0.0.0.0"]

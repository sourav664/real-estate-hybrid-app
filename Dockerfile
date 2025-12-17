# =====================
# Builder stage
# =====================
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

# ✅ INSTALL RUNTIME DEPENDENCY (IMPORTANT)
RUN apt-get update && apt-get install -y --no-install-recommends \
    libgomp1 \
    && rm -rf /var/lib/apt/lists/*


COPY --from=builder /install /usr/local

COPY ./data/raw/real_estate.csv ./data/raw/real_estate.csv

COPY ./my_app/ ./my_app/
COPY ./models/ ./models/
COPY ./run_information.json ./

ENV PORT=8000
EXPOSE 8000

# run the streamlit app
CMD ["sh", "-c", "streamlit run my_app/home.py --server.port=$PORT --server.address=0.0.0.0"]


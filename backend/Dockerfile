# Build stage: install dependencies into an isolated prefix.
FROM python:3.12-slim AS builder
WORKDIR /build
COPY requirements.txt .
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt

# Runtime stage: no build tools, runs as an unprivileged user.
FROM python:3.12-slim
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PORT=8080
RUN useradd --system --uid 10001 --no-create-home --shell /usr/sbin/nologin appuser
WORKDIR /app
COPY --from=builder /install /usr/local
COPY nutrilens_api ./nutrilens_api
USER 10001
EXPOSE 8080
# One worker with threads keeps the in-memory rate limiter coherent per instance.
CMD ["sh", "-c", "exec gunicorn --bind 0.0.0.0:${PORT} --workers 1 --threads 8 --timeout 120 'nutrilens_api.app:create_app()'"]

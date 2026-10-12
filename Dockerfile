FROM python:3.12-slim-bookworm@sha256:34386ef0cb081344d7ec1c103ba398e6e9f64e9ab3a1509accc92a4e24a07258

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app

# Create the dedicated unprivileged user and group
RUN groupadd --system --gid 10001 app \
 && useradd  --system --uid 10001 --gid app \
             --no-create-home --shell /usr/sbin/nologin app

# Install your Python packages
COPY app/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy app files and change ownership to the 'app' user
COPY --chown=app:app app/ /app/

# Drop root privileges
USER app

EXPOSE 8080

# Adding a /healthz endpoint for app
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
  CMD ["python", "-c", "import urllib.request,sys; sys.exit(0 if urllib.request.urlopen('http://127.0.0.1:8080/healthz', timeout=2).status == 200 else 1)"]

CMD ["gunicorn", \
     "--bind", "0.0.0.0:8080", \
     "--workers", "4", \
     "--worker-tmp-dir", "/dev/shm", \
     "--access-logfile", "-", \
     "--error-logfile", "-", \
     "app:app"]

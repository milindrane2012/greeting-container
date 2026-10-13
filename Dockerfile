ARG PYTHON_IMAGE=python:3.12-slim-bookworm@sha256:34386ef0cb081344d7ec1c103ba398e6e9f64e9ab3a1509accc92a4e24a07258


################################# Stage 1: In this stage build required dependencies #################################

FROM ${PYTHON_IMAGE} AS builder

ENV PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PYTHONDONTWRITEBYTECODE=1

RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

WORKDIR /build

COPY app/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt


################################# Stage 2: runtime image #################################

FROM ${PYTHON_IMAGE} AS runtime

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PATH="/opt/venv/bin:$PATH"

# Create a non-root user like app with fixed UID/GID, no shell, no home
RUN groupadd --system --gid 10001 app \
 && useradd  --system --uid 10001 --gid app \
             --no-create-home --shell /usr/sbin/nologin app

WORKDIR /app

# Copy only the installed dependencies from Stage 1 : builder
COPY --from=builder /opt/venv /opt/venv

# Change the ownership of app folder to app:app
COPY --chown=app:app app/ /app/

USER app

EXPOSE 8080

# Adding a /healthz endpoint for app
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
  CMD ["python", "-c", "import urllib.request,sys; sys.exit(0 if urllib.request.urlopen('http://127.0.0.1:8080/healthz', timeout=2).status == 200 else 1)"]

CMD ["gunicorn", \
     "--bind", "0.0.0.0:8080", \
     "--workers", "2", \
     "--worker-tmp-dir", "/dev/shm", \
     "--access-logfile", "-", \
     "--error-logfile", "-", \
     "app:app"]

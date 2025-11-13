FROM python:3.12.12-alpine3.22 AS base

# Metadata labels (OWASP recommendation)
LABEL maintainer="placheckij" \
      version="1.0.0" \
      description="Observability Test App" \
      org.opencontainers.image.source="https://github.com/placheckij/observability"

USER root
# Install packages and create non-root user in single layer (CIS 4.2)
RUN apk -U upgrade && \
    apk add --no-cache curl tini && \
    rm -rf /var/cache/apk/* && \
    addgroup -g 1888 observabilitygroup && \
    adduser -D -h /observability -G observabilitygroup -u 1888 observabilityuser

ENV PYTHONUNBUFFERED=true

# Switch to non-root user (CIS 4.1, OWASP recommendation)
USER observabilityuser
WORKDIR /observability

FROM base AS poetry
RUN python -m pip install --no-cache-dir poetry==2.2.*
ENV PATH=/observability/.local/bin:$PATH \
    POETRY_VIRTUALENVS_IN_PROJECT=true
# Copy only necessary files for dependency installation (CIS 4.9)
COPY --chown=observabilityuser:observabilitygroup ./pyproject.toml ./poetry.lock ./
RUN /observability/.local/bin/poetry sync --no-root --no-ansi --no-interaction --no-cache

# Runtime stage starts from base (not poetry) to exclude Poetry from final image
# This reduces image size by ~50MB and removes unnecessary build tools from production
FROM base AS runtime
ENV PATH=/observability/.venv/bin:$PATH
COPY --chown=observabilityuser:observabilitygroup --from=poetry /observability/.venv /observability/.venv
# Copy only application code (CIS 4.9)
COPY --chown=observabilityuser:observabilitygroup ./api ./api
COPY --chown=observabilityuser:observabilitygroup ./core ./core
COPY --chown=observabilityuser:observabilitygroup ./main.py ./utils.py ./
COPY --chown=observabilityuser:observabilitygroup ./pyproject.toml ./

# Set proper file permissions (OWASP recommendation)
USER root
RUN chmod -R 550 /observability/api /observability/core && \
    find /observability -maxdepth 1 -type f -name "*.py" -exec chmod 440 {} \;
USER observabilityuser

# Health check (CIS 4.7)
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
    CMD curl -f http://localhost:3000/health || exit 1

# Use tini to handle signals properly and avoid running as PID 1 (OWASP recommendation)
ENTRYPOINT ["/sbin/tini", "--"]
CMD ["/observability/.venv/bin/uvicorn", "--host", "0.0.0.0", "--port", "3000", "--log-config", "core/logging_setup.json", "--log-level", "info", "--workers", "1", "--lifespan", "on", "main:app"]

# Hardened image following https://github.com/placheckij/dockerfile-wizardry
# (CIS Docker Benchmark v1.9.0 & OWASP Docker Security Cheat Sheet). "Spell #N" refers to its README.

# Spell #1: parameterized base image, pinned by digest (CIS 4.2, 5.28)
# The tag says what we intend; the digest says exactly which bytes we get.
# Bump both together when the dockerfile-wizardry base image check reports a new digest.
ARG PYTHON_VERSION=3.14.10
ARG ALPINE_VERSION=3.24
FROM python:${PYTHON_VERSION}-alpine${ALPINE_VERSION}@sha256:eb2c62658b8d51bff0acc408504b76521d02030de56a8a3c1e830083e89b89d2 AS base

# Spell #2: metadata labels
LABEL maintainer="placheckij" \
      version="1.0.0" \
      description="Observability Test App" \
      org.opencontainers.image.source="https://github.com/placheckij/observability"

USER root
# Spell #3 & #4: minimal packages (only tini, the health check uses Python) and a non-root user (CIS 4.1, 4.3, 4.6)
# Packages are deliberately not version-pinned: Alpine keeps only the current version of each
# package per release, so a pin breaks the build as soon as a fix is published.
# hadolint ignore=DL3018
RUN apk -U upgrade && \
    apk add --no-cache tini && \
    rm -rf /var/cache/apk/* && \
    addgroup -g 1888 observabilitygroup && \
    adduser -D -h /observability -G observabilitygroup -u 1888 observabilityuser

ENV PYTHONUNBUFFERED=true

USER observabilityuser
WORKDIR /observability

# Stage 2: dependency installation (Poetry stays in this stage, never in the final image)
FROM base AS poetry
# Spell #5: pinned build tool, no pip cache
RUN python -m pip install --no-cache-dir poetry==2.2.*
# SOURCE_DATE_EPOCH makes Python write hash-based .pyc files, so two builds of the same
# commit give identical bytecode (only its presence matters, the value is never stored).
ARG SOURCE_DATE_EPOCH=0
ENV SOURCE_DATE_EPOCH=${SOURCE_DATE_EPOCH} \
    PATH=/observability/.local/bin:$PATH \
    POETRY_VIRTUALENVS_IN_PROJECT=true

# Spell #6: layer caching - dependency manifests first, so code changes don't reinstall them (CIS 4.8)
COPY --chown=observabilityuser:observabilitygroup ./pyproject.toml ./poetry.lock ./
# --only main: runtime dependencies only (no ruff/isort); --compile: the runtime filesystem is
# read-only, so .pyc files cannot be written later
RUN poetry sync --only main --no-root --compile --no-ansi --no-interaction --no-cache

# Stage 3: assemble the runtime filesystem
FROM base AS pruned

# Spell #7: multi-stage build - copy only the virtualenv
COPY --chown=observabilityuser:observabilitygroup --from=poetry /observability/.venv /observability/.venv

# Spell #8: selective file copying (CIS 4.8, 4.9)
COPY --chown=observabilityuser:observabilitygroup ./api ./api
COPY --chown=observabilityuser:observabilitygroup ./core ./core
COPY --chown=observabilityuser:observabilitygroup ./main.py ./utils.py ./
# utils.py reads the app version from pyproject.toml at startup
COPY --chown=observabilityuser:observabilitygroup ./pyproject.toml ./

# Spell #9: restrictive permissions
# The app user must not own what it runs: an owner can always chmod its own files back to
# writable, and a writable directory lets entries be renamed or replaced. Everything under
# /observability is root-owned and reachable by the app user only through the read-only group.
USER root
RUN chown -R root:observabilitygroup /observability && \
    chmod -R g-w,o-rwx /observability && \
    chmod -R 550 /observability/api /observability/core && \
    chmod 440 /observability/main.py /observability/utils.py /observability/pyproject.toml

# Spell #10: prune what the app never runs (CIS 4.3)
# Defense in depth, not a barrier: Python and the busybox shell are still present.
# The apk database (/lib/apk/db) stays on purpose so vulnerability scanners can see OS packages.
RUN /usr/local/bin/python -m pip uninstall -y pip && \
    PYLIB=$(python -c "import sysconfig; print(sysconfig.get_path('stdlib'))") && \
    rm -rf /usr/local/include "$PYLIB"/ensurepip "$PYLIB"/idlelib "$PYLIB"/tkinter \
           "$PYLIB"/turtledemo "$PYLIB"/pydoc_data "$PYLIB"/lib-dynload/_tkinter* \
           /usr/local/bin/idle* /usr/local/bin/pydoc* /usr/local/bin/python*-config && \
    rm -f /usr/bin/wget /usr/bin/nc /usr/bin/telnet /usr/bin/ftpget /usr/bin/ftpput \
          /usr/bin/tftp /usr/bin/ssl_client /bin/wget /bin/nc /bin/telnet /bin/ssl_client && \
    rm -rf /sbin/apk /lib/libapk* /var/cache/apk /etc/apk && \
    rm -rf /observability/.venv/bin/pip* /observability/.venv/lib/python*/site-packages/pip*
USER observabilityuser

# Stage 4: flatten into the final image
# Files deleted in a later layer still sit in the layers below and can be extracted.
# Copying the pruned filesystem into scratch drops them for real.
# scratch carries no metadata, so ENV, LABEL, USER, ... are declared again.
FROM scratch AS runtime
ARG PYTHON_VERSION
# hadolint ignore=DL3067
COPY --from=pruned / /
ENV PATH=/observability/.venv/bin:/usr/local/bin:/usr/local/sbin:/usr/sbin:/usr/bin:/sbin:/bin \
    LANG=C.UTF-8 \
    PYTHON_VERSION=${PYTHON_VERSION} \
    PYTHONUNBUFFERED=true
LABEL maintainer="placheckij" \
      version="1.0.0" \
      description="Observability Test App" \
      org.opencontainers.image.source="https://github.com/placheckij/observability"
USER observabilityuser
WORKDIR /observability

# Spell #11: explicit port declaration
EXPOSE 3000

# Spell #12: health check (CIS 4.5) - Python instead of curl, one less binary in the image
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
    CMD ["/observability/.venv/bin/python", "-c", "import urllib.request as u; u.urlopen('http://localhost:3000/health', timeout=2)"]

# Spell #13: graceful shutdown signal
STOPSIGNAL SIGTERM

# Spell #14: tini as PID 1 handles signals and reaps zombies
ENTRYPOINT ["/sbin/tini", "--"]
CMD ["/observability/.venv/bin/uvicorn", "--host", "0.0.0.0", "--port", "3000", "--log-config", "core/logging_setup.json", "--log-level", "info", "--workers", "1", "--lifespan", "on", "main:app"]

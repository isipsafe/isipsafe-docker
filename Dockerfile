# syntax=docker/dockerfile:1.7
ARG PYTHON_IMAGE=python:3.13-alpine

FROM ${PYTHON_IMAGE} AS build
ARG ISIPSAFE_VERSION=0.1.0
COPY wheels/ /wheels/
RUN python -m venv /opt/isipsafe \
 && if ls /wheels/isipsafe-*.whl >/dev/null 2>&1; then \
      /opt/isipsafe/bin/pip install --no-cache-dir --no-index /wheels/isipsafe-*.whl; \
    else \
      /opt/isipsafe/bin/pip install --no-cache-dir "isipsafe==${ISIPSAFE_VERSION}"; \
    fi \
 && /opt/isipsafe/bin/isipsafe --version

FROM ${PYTHON_IMAGE}
ARG ISIPSAFE_VERSION=0.1.0
LABEL org.opencontainers.image.title="isipsafe" \
      org.opencontainers.image.description="Check and report IP addresses with isIPsafe, and keep a firewall blocklist in sync." \
      org.opencontainers.image.url="https://isipsafe.com" \
      org.opencontainers.image.documentation="https://github.com/isipsafe/isipsafe-docker" \
      org.opencontainers.image.source="https://github.com/isipsafe/isipsafe-docker" \
      org.opencontainers.image.vendor="WaveCentric" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.version="${ISIPSAFE_VERSION}"

RUN apk add --no-cache tini \
 && addgroup -S -g 10001 isipsafe \
 && adduser -S -u 10001 -G isipsafe -h /home/isipsafe isipsafe \
 && mkdir -p /data \
 && chown isipsafe:isipsafe /data

COPY --from=build /opt/isipsafe /opt/isipsafe
COPY --chmod=0755 docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh

ENV PATH="/opt/isipsafe/bin:${PATH}" \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

USER isipsafe
WORKDIR /data
VOLUME ["/data"]
ENTRYPOINT ["/sbin/tini", "--", "docker-entrypoint.sh"]
CMD ["--help"]

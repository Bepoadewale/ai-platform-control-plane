# Keep the local control-plane image on the maintained Debian Bookworm stream.
# The floating `slim` tag moved to a base carrying newly disclosed OpenSSL CVEs.
FROM python:3.12-slim-bookworm
# Pull Debian security fixes into the otherwise slim base. The CI image scan enforces this rather
# than relying on the mutable upstream image refresh cadence.
RUN apt-get update \
    && apt-get upgrade -y \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY pyproject.toml ./
COPY control-plane/src ./control-plane/src
RUN pip install --no-cache-dir .
RUN mkdir -p /app/state /app/environments && chown -R 65532:65532 /app
USER 65532:65532
EXPOSE 8000
CMD ["uvicorn", "platform_control_plane.api.main:app", "--host", "0.0.0.0", "--port", "8000"]

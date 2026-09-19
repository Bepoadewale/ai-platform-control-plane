FROM python:3.12-slim@sha256:8a4b6e8c0a17ba086aa1440a9c9d6b40f0b27e3d24709bcdb4b28993ef6f54df
WORKDIR /app
COPY pyproject.toml ./
COPY control-plane/src ./control-plane/src
RUN pip install --no-cache-dir .
USER 65532:65532
EXPOSE 8000
CMD ["uvicorn", "platform_control_plane.api.main:app", "--host", "0.0.0.0", "--port", "8000"]

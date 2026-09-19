FROM python:3.12-slim
WORKDIR /app
COPY pyproject.toml ./
COPY control-plane/src ./control-plane/src
RUN pip install --no-cache-dir .
RUN mkdir -p /app/state /app/environments && chown -R 65532:65532 /app
USER 65532:65532
EXPOSE 8000
CMD ["uvicorn", "platform_control_plane.api.main:app", "--host", "0.0.0.0", "--port", "8000"]

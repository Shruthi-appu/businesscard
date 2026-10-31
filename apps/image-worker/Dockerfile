FROM python:3.12-slim
WORKDIR /app
COPY apps/image-worker /app
RUN pip install --no-cache-dir pillow
CMD ["python", "-m", "worker.main"]

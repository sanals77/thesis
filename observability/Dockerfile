FROM python:3.11-slim

WORKDIR /app

RUN pip install --no-cache-dir prometheus-client kubernetes

COPY policy-metrics-exporter.py .

RUN chmod +x policy-metrics-exporter.py

USER nobody

EXPOSE 9091

CMD ["python", "policy-metrics-exporter.py"]

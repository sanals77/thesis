# Multi-stage build for minimal image size
FROM python:3.11-slim AS builder

WORKDIR /build

# Install dependencies to a temporary location
COPY requirements.txt .
RUN pip install --no-cache-dir --target=/install -r requirements.txt

# Final stage
FROM python:3.11-slim

# Create non-root user for security
RUN groupadd -r appuser && useradd -r -g appuser appuser

WORKDIR /app

# Copy dependencies from builder
COPY --from=builder --chown=appuser:appuser /install /app/packages

# Copy application code
COPY --chown=appuser:appuser worker.py .
COPY --chown=appuser:appuser requirements.txt .

# Set PYTHONPATH to include packages
ENV PYTHONPATH=/app/packages:$PYTHONPATH
ENV PATH=/app/packages/bin:$PATH

# Run as non-root user
USER appuser

# No exposed ports for background worker

# Run application
CMD ["python", "worker.py"]

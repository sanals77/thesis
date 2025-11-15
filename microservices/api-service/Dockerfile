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
COPY --chown=appuser:appuser app.py .
COPY --chown=appuser:appuser requirements.txt .

# Set PYTHONPATH to include packages
ENV PYTHONPATH=/app/packages:$PYTHONPATH
ENV PATH=/app/packages/bin:$PATH

# Run as non-root user
USER appuser

# Expose port
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8080/health')" || exit 1

# Run application with gunicorn
CMD ["python", "-m", "gunicorn", "--bind", "0.0.0.0:8080", "--workers", "4", "--timeout", "60", "app:app"]

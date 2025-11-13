# Multi-stage Dockerfile for Data Collection Service
# Stage 1: Build stage
FROM python:3.11-slim AS builder

WORKDIR /app

# Install build dependencies
RUN apt-get update && apt-get install -y \
    gcc \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements first for better caching
COPY app/requirements.txt .

# Install Python dependencies
RUN pip install --no-cache-dir --user -r requirements.txt

# Stage 2: Runtime stage
FROM gcr.io/distroless/python3-debian11:latest

# Copy Python packages from builder
COPY --from=builder /root/.local /root/.local

# Create non-root user
USER 1001:1001

# Set working directory
WORKDIR /app

# Copy application code
COPY --chown=1001:1001 app/ .

# Add labels for metadata
LABEL maintainer="devops@company.com" \
      version="1.0.0" \
      description="Data Collection Service" \
      org.opencontainers.image.source="https://github.com/company/data-collection-service"

# Expose port
EXPOSE 8000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD python -c "import requests; requests.get('http://localhost:8000/health')" || exit 1

# Set Python path
ENV PYTHONPATH=/root/.local/lib/python3.11/site-packages

# Run application
CMD ["python", "-m", "uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
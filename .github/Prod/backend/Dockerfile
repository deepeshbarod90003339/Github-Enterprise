# Stage 1: Build the Python app
FROM python:3.11-slim AS build

WORKDIR /usr/src/app

# Copy requirements.txt first for caching
COPY requirements.txt ./

# Install dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Copy the rest of the app files
COPY . .

# Stage 2: Runtime stage
FROM python:3.11-slim

WORKDIR /usr/src/app

# Copy installed packages from build stage
COPY --from=build /usr/local/lib/python3.11/site-packages /usr/local/lib/python3.11/site-packages
COPY --from=build /usr/local/bin /usr/local/bin

# Copy application code from build stage
COPY --from=build /usr/src/app .

EXPOSE 8000

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
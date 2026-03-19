# Use an official lightweight Python image
FROM python:3.11-slim

# Set the working directory inside the container
WORKDIR /app

# Install gunicorn for a production-ready server
RUN pip install gunicorn

# Copy and install dependencies from requirements.txt
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy the rest of your application code into the container
COPY . .

# Cloud Run provides the PORT environment variable, defaulting to 8080
# Tell Gunicorn to listen on this port
CMD ["gunicorn", "--workers=4", "--bind=0.0.0.0:8080", "api:app"]

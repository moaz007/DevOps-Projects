# 1) Base image with Python
FROM python:3.11-slim

# 2) Set workdir inside the container
WORKDIR /app

# 3) Install dependencies first (better layer caching)
COPY app/requirements.txt /app/requirements.txt
RUN pip install --no-cache-dir --upgrade pip \
    && pip install --no-cache-dir -r /app/requirements.txt

# 4) Copy the app code
COPY app/ /app/

# 5) Expose and run
EXPOSE 5000
CMD ["python", "app.py"]

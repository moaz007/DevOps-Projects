FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1

RUN useradd -m appuser
WORKDIR /app

COPY app/requirements.txt /app/requirements.txt
RUN pip install --upgrade pip && pip install -r requirements.txt

COPY app/ /app/

EXPOSE 5000
USER appuser

CMD ["gunicorn", "-b", "0.0.0.0:5000", "--workers", "2", "app:app"]

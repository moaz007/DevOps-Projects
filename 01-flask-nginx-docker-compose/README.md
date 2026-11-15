# DevOps Project 1 — Flask + Docker + Nginx + Docker Compose

This project is a minimal Python/Flask web app with:
- `/` → returns a greeting
- `/health` → returns `{"status": "ok"}`

It is containerized with Docker, fronted by Nginx as a reverse proxy, and orchestrated with Docker Compose.

## How to run

From the project root (`devops-project-1/`):

```bash
docker compose build
docker compose up -d

## Then test:
curl -i http://localhost:8080/
curl -i http://localhost:8080/health
curl -i http://localhost:8080/nginx-health


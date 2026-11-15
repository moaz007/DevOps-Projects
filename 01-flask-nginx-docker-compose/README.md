# Project 1 — Containerized Flask App with Nginx Reverse Proxy & Docker Compose

## What This Project Does
In this project, I containerized a Python Flask web application using **Docker** and placed an **Nginx** reverse proxy in front of it using **Docker Compose**. Instead of exposing the Python application server directly to external traffic, Nginx receives incoming HTTP requests on port `8080` and forwards them internally over a private Docker bridge network to Gunicorn running on port `5000`.

---

## How Traffic Flows (Architecture Flowchart)

```text
[ Browser / Client: http://localhost:8080 ]
                    │
                    ▼
┌───────────────────────────────────────────┐
│        Nginx Container (Port 80)          │
│  - Serves /nginx-health directly          │
│  - Proxies / and /health to app:5000      │
└───────────────────┬───────────────────────┘
                    │  (Internal Docker Bridge Network: app_net)
                    ▼
┌───────────────────────────────────────────┐
│   Flask + Gunicorn Container (Port 5000)  │
│  - Non-root user (appuser)                │
│  - Healthcheck verified before Nginx boots│
└───────────────────────────────────────────┘
# Project 2 — Automated CI/CD Pipeline with GitHub Actions & GHCR

![Project 2 CI](https://github.com/moaz007/DevOps-Projects/actions/workflows/project2-ci.yml/badge.svg)

## What This Project Does
In this project, I built an automated **CI/CD pipeline** using **GitHub Actions** for a containerized Python Flask service. Whenever changes are pushed to `02-flask-github-actions-ghcr-cicd/`, GitHub Actions automatically runs unit tests with `pytest`, builds the Docker image, and publishes tagged images (`latest` and `sha-<commit>`) to **GitHub Container Registry (GHCR)**.

---

## How the Pipeline Flows (Architecture Flowchart)

```text
[ Push / Pull Request to 02-flask-github-actions-ghcr-cicd/ ]
                             │
                             ▼
┌────────────────────────────────────────────────────────┐
│                 GitHub Actions Runner                  │
│  1. Checkout Code & Setup Python (with pip caching)    │
│  2. Run Unit Tests (pytest)                            │
│  3. Build Docker Image (Docker Buildx)                 │
│  4. Push Image to GHCR (on push events only)           │
└────────────────────────────┬───────────────────────────┘
                             │
                             ▼
┌────────────────────────────────────────────────────────┐
│         GitHub Container Registry (ghcr.io)            │
│  - ghcr.io/moaz007/02-flask-github-actions-ghcr-cicd:latest
│  - ghcr.io/moaz007/02-flask-github-actions-ghcr-cicd:sha-*
└────────────────────────────────────────────────────────┘
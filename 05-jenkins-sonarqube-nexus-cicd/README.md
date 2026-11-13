# Project 5 — Automated CI/CD Pipeline with Jenkins, SonarQube & Nexus

## What This Project Does
In this project, I built an end-to-end **Continuous Integration (CI) pipeline** on AWS using **Jenkins** as the central automation server. Whenever code is pushed to GitHub, Jenkins automatically pulls the code, compiles it with Maven, checks code style and quality through **SonarQube**, and stores the versioned `.war` artifact in **Sonatype Nexus**—sending real-time build notifications to Slack.

> **Want to rebuild this from scratch?** Follow the step-by-step setup guide in [`RUNBOOK.md`](RUNBOOK.md).

---

## How the Pipeline Flows (Architecture Flowchart)

```text
[ Developer pushes code to GitHub ]
                 │
                 ▼  (GitHub Webhook Trigger)
┌────────────────────────────────────────────────────────┐
│                    Jenkins Server                      │
│  1. Checkout Code  ──▶  2. Maven Build & Unit Tests    │
│  3. Checkstyle     ──▶  4. SonarQube Code Analysis     │
│  5. Quality Gate   ──▶  6. Upload WAR to Nexus         │
└────────┬───────────────────────────────┬───────────────┘
         │                               │
         ▼                               ▼
[ SonarQube Server ]            [ Sonatype Nexus ]
 (Code Quality & Bugs)          (Artifact Storage)
         │
         ▼
[ Slack Notification ] (Pass / Fail Alert)
```

---

## Key Components & Plugins Used
1. **Jenkins (Pipeline Orchestrator):**
   - Configured a declarative `Jenkinsfile` triggered automatically via GitHub Webhooks (`GitHub Integration` plugin).
   - Installed core pipeline plugins including **Pipeline**, **SonarQube Scanner**, **Nexus Artifact Uploader**, **Pipeline Utility Steps**, and **Slack Notification**.
2. **SonarQube (Code Quality & Security Gate):**
   - Analyzed Java source code and JaCoCo test coverage reports, blocking the pipeline from publishing broken or low-quality code if the **Quality Gate** failed.
3. **Sonatype Nexus (Artifact Repository):**
   - Stored versioned `.war` build artifacts in a hosted Maven repository so tested builds can be promoted cleanly to deployment environments.

---

## Biggest Problem I Solved (Debugging Story)
- **The Problem:** During pipeline runs, the SonarQube analysis stage began timing out and returning **HTTP 502 Bad Gateway** errors even though the EC2 instance was running.
- **How I Found It:** I SSH'd into the SonarQube EC2 instance, checked disk usage (`df -h`), and inspected service logs—discovering the root volume had hit **100% disk capacity**, which caused SonarQube's internal Elasticsearch engine to lock the index into read-only mode and crash.
- **How I Fixed It:**
  1. Cleared old system journal logs (`journalctl --vacuum-time=2d`) and package caches to reclaim disk space.
  2. Reset Elasticsearch's read-only index block and restarted the SonarQube service.
  3. Re-ran the Jenkins pipeline and verified the Quality Gate and Nexus artifact upload succeeded end-to-end.
# Project 3 — Hosting a Multi-Tier Web App on AWS (Lift & Shift) a multi-tier Java web application

## What This Project Does
In this project, I deployed **vProfile** (a Java web application) onto AWS Cloud using virtual machines (EC2) and connected it to my own domain (`devopsmoaz.de`). Instead of putting everything on one server, each part of the app runs on its own dedicated server so it can scale and stay secure.

> **Want to rebuild this from scratch?** Follow the step-by-step commands and AWS Console settings in [`RUNBOOK.md`](RUNBOOK.md).
---

## How Traffic Flows (Architecture Flowchart)

```text
[ User Browser: devopsmoaz.de ]
              │
              ▼  (Port 80)
[ AWS Application Load Balancer ]
              │
              ▼  (Port 8080)
┌─────────────────────────────────────────┐
│         Auto Scaling Group              │
│   [ App Server: Tomcat + vProfile ]     │
└──────┬──────────────┬──────────────┬────┘
       │              │              │
 (Port 3306)    (Port 11211)   (Port 5672)
       ▼              ▼              ▼
[ Database ]    [ Memcached ]  [ RabbitMQ ]
db01.vprofile.pk mc01.vprofile.pk rmq01.vprofile.pk
```

---

## The Building Blocks I Set Up
1. **Route 53 (DNS):**
   - **Public DNS:** Pointed my domain (`devopsmoaz.de`) to the AWS Load Balancer.
   - **Private DNS (`vprofile.pk`):** Gave my backend servers clean internal names (`db01.vprofile.pk`, `mc01.vprofile.pk`, `rmq01.vprofile.pk`) so the app doesn't break if a server's IP address changes.
2. **Security Groups (Firewalls):**
   - **Load Balancer:** Open to the internet on port `80` (HTTP).
   - **App Server:** Only accepts traffic on port `8080` coming from the Load Balancer.
   - **Backend Servers:** Only accept traffic on ports `3306` (MySQL), `11211` (Memcached), and `5672` (RabbitMQ) coming from the App Server.
3. **Golden AMI & Auto Scaling:**
   - Once the App Server was configured and tested, I saved it as a custom **AMI (Amazon Machine Image)** and attached it to an **Auto Scaling Group** so AWS can launch identical copies automatically.

---

## Biggest Problem I Solved (Debugging Story)
- **The Problem:** The login page loaded fine in the browser, and the user `admin_vp` existed in the database, **but every login attempt failed with `"User Not Found"`**.
- **How I Found It:** I checked Tomcat's log file (`/var/log/tomcat10/catalina.out`) and saw a database connection error. When I inspected the app's `application.properties` file, I noticed the database host was written as `db01` instead of its full private domain `db01.vprofile.pk`.
- **How I Fixed It:**
  1. Updated `application.properties` with `db01.vprofile.pk` and rebuilt the `.war` file using Maven.
  2. Deployed the fixed app to `vprofile-app01` and verified login worked.
  3. Created a new **Golden AMI**, updated the **Launch Template**, and refreshed the **Auto Scaling Group** so new servers booted with the fix already baked in.
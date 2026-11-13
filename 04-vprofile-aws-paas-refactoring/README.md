# Project 4 — Re-Architecting vProfile on AWS (Managed PaaS Refactoring)

## What This Project Does
In this project, I re-architected the **vProfile** multi-tier Java web application from a manual virtual machine setup (Project 3) into a cloud-native **AWS Managed PaaS** architecture. 

**The 4 Problems This Solves:**
1. **High Operational Overhead & Uptime Struggles:** Eliminates manual OS updates, manual database patching, custom AMI baking, and server babysitting so teams can focus on the application instead of infrastructure maintenance.
2. **Upfront CAPEX & Unpredictable OPEX:** Replaces fixed hardware investments and idle server costs with pay-as-you-go managed AWS services.
3. **Difficult-to-Automate Manual Processes:** Moves away from manual server provisioning toward automated deployments and built-in scaling through Elastic Beanstalk.
4. **Secure Global Delivery:** Adds a global Content Delivery Network (CloudFront) with managed SSL/TLS certificates for fast, encrypted HTTPS access on `devopsmoaz.de`.

> **Want to rebuild this from scratch?** Follow the step-by-step build guide in [`RUNBOOK.md`](RUNBOOK.md).

---

## How Traffic Flows (Architecture Flowchart)

```text
[ User Browser: devopsmoaz.de (HTTPS) ]
                  │
                  ▼
     [ Amazon CloudFront (CDN + SSL) ]
                  │
                  ▼  (Port 443 / 80)
┌───────────────────────────────────────────────────┐
│            AWS Elastic Beanstalk                  │
│   [ Load Balancer + Auto Scaling + Tomcat/Nginx ] │
└────────┬────────────────┬────────────────┬────────┘
         │                │                │
   (Port 3306)      (Port 11211)     (Port 61617/5672)
         ▼                ▼                ▼
  [ Amazon RDS ]   [ ElastiCache ]   [ Amazon MQ ]
     (MySQL)         (Memcached)       (ActiveMQ)
```

---

## What Changed From Project 3 (Lift & Shift → Cloud-Native PaaS)
1. **App Servers & Scaling (`EC2 + Manual AMI` → `AWS Elastic Beanstalk`):**
   - Elastic Beanstalk now automatically provisions and scales the Tomcat/Nginx instances, manages the Load Balancer, and handles app deployments without baking custom AMIs.
2. **Database (`Self-Hosted MariaDB on EC2` → `Amazon RDS`):**
   - Replaced the manual database VM with managed **Amazon RDS (MySQL)** for automated backups, patching, and high availability.
3. **Caching & Messaging (`EC2 VMs` → `Amazon ElastiCache & Amazon MQ`):**
   - Moved Memcached to **Amazon ElastiCache** and replaced the manual message broker VM with **Amazon MQ (ActiveMQ)**.
4. **Global Edge & SSL (`HTTP on ALB` → `Amazon CloudFront + ACM SSL`):**
   - Added **Amazon CloudFront** as a Content Delivery Network in front of the Elastic Beanstalk Load Balancer with a free SSL/TLS certificate from **AWS Certificate Manager (ACM)** so `devopsmoaz.de` serves securely over HTTPS.
# Multi-Tier Web Application Deployment on Google Cloud Platform (GCP)

An end-to-end, multi-tier cloud deployment of the `vProfile` Java web application on Google Cloud Platform (GCP), automated via modular `gcloud` CLI shell scripts with custom VPC networking, Private Service Access, managed relational/caching backends, Golden Image autoscaling, and Global HTTPS Load Balancing.

---

## Architecture & Traffic Flow

```text
[ Client Browser: https://vprogcp.<your-domain> ]
                       │
                       ▼  (HTTP :80 → 301 Redirect to HTTPS :443)
┌────────────────────────────────────────────────────────────────────┐
│        Global External HTTP(S) Load Balancer (Static IP)           │
│     Google-Managed Wildcard SSL Cert (Certificate Manager)         │
└──────────────────────────────┬─────────────────────────────────────┘
                               │  (Health Check: HTTP :8080 /)
                               ▼
┌────────────────────────────────────────────────────────────────────┐
│                  Custom VPC (vprofile-vpc)                         │
│                                                                    │
│  ┌──────────────────────────┐   ┌───────────────────────────────┐  │
│  │ Public Subnets (01 & 02) │   │ Private Subnets (01 & 02)     │  │
│  │ - Bastion Host (SSH)     │   │ - Managed Instance Group      │  │
│  │ - Cloud Router + NAT     │   │   (Tomcat 10, Min 2 / Max 4)  │  │
│  └──────────────────────────┘   └───────────────┬───────────────┘  │
│                                                 │                  │
│         ┌───────────────────────────────────────┘                  │
│         ▼  (Cloud DNS Private Zone: vprofile.internal)             │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │ Private Service Access (VPC Peering)                         │  │
│  │ - Cloud SQL for MySQL (vprodb.vprofile.internal:3306)        │  │
│  │ - Memorystore for Memcached (vpromc.vprofile.internal:11211) │  │
│  └──────────────────────────────────────────────────────────────┘  │
└────────────────────────────────────────────────────────────────────┘
```

---

## Deployment Evolution & Automation Stages

* **Stage 1 — Custom VPC, Cloud NAT & Private Managed Backends (`backend.sh`):** Built an isolated custom VPC (`vprofile-vpc`) with two public and two private subnets, configured Cloud Router + Cloud NAT for outbound private-subnet package downloads, established Private Service Access (VPC peering) for Google-managed services, provisioned private Cloud SQL (MySQL) and Memorystore (Memcached) instances, and seeded the `accounts` database schema via an SSH Bastion host.
* **Stage 2 — Private DNS, Golden Image & Global HTTP Load Balancer (`frontend_1.sh`):** Created a Cloud DNS private zone (`vprofile.internal`) mapping `vprodb.vprofile.internal` and `vpromc.vprofile.internal` to backend private IPs, baked a configured Tomcat 10 + Java 17 instance (`vprofile-golden`) into a custom Compute Engine image (`vprofile-image`), deployed a CPU-autoscaled Managed Instance Group (2–4 `e2-micro` VMs), and exposed it behind a Global HTTP Load Balancer with a reserved static IP.
* **Stage 3 — Wildcard SSL Termination & HTTPS Enforcement (`frontend_2.sh`):** Provisioned a Google-managed wildcard SSL certificate via Certificate Manager (`*.<your-domain>`), attached a Certificate Map to the Target HTTPS Proxy, and bound port `443` to the global static IP.
* **Stage 4 — Resource Verification & Dependency-Ordered Teardown (`list.sh` & `rollback.sh`):** Audited all billable GCP resources and executed reverse-dependency teardown (`rollback.sh`) across Load Balancers, MIGs, custom images, Cloud SQL, Memorystore, Cloud NAT, subnets, and certificates.

---

## Key Concepts Demonstrated

* **Cross-Cloud Architecture Translation (AWS → GCP):** Mapped AWS VPC, NAT Gateway, VPC Endpoints, RDS, ElastiCache, Route 53 Private Hosted Zones, Golden AMIs, Auto Scaling Groups, and ALB directly to GCP Custom VPC, Cloud NAT, Private Service Access, Cloud SQL, Memorystore, Cloud DNS, Compute Engine Custom Images, Managed Instance Groups (MIG), and Global External HTTP(S) Load Balancing.
* **Zero-Public-IP Application Tier:** Placed all application VMs in private subnets (`--no-address`), routing outbound OS/package traffic through Cloud NAT and administrative SSH access exclusively through a hardened Bastion host.
* **Private Service Access & Internal DNS Discovery:** Connected Compute Engine VMs to Google-managed Cloud SQL and Memorystore over private RFC1918 peering (`servicenetworking.googleapis.com`) using internal Cloud DNS `A` records (`vprodb.vprofile.internal`, `vpromc.vprofile.internal`).
* **Declarative Infrastructure Scripting & Cost Hygiene:** Automated deployment and reverse-order cleanup via parameterized `gcloud` CLI scripts (`backend.sh`, `frontend_1.sh`, `frontend_2.sh`, `list.sh`, `rollback.sh`), followed by full resource audit verification (`Listed 0 items` across all billable services).

---

## Repository Contents

* **`README.md`** — GCP architecture diagram, implementation stages, and key engineering concepts.
* **`RUNBOOK.md`** — Step-by-step execution, DNS/SSL verification, resource audit, and cost-safe teardown guide.
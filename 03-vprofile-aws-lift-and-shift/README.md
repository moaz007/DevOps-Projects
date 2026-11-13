# Project 3 — Multi-Tier Web Application Deployment on AWS (Lift & Shift)

## Overview
End-to-end deployment of the **vProfile** multi-tier Java web application on AWS using an Infrastructure-as-a-Service (IaaS) Lift & Shift architecture. The stack decouples presentation, application, caching, queuing, and persistent database tiers across AWS Availability Zones with private DNS service discovery and automated scaling.

---

## Architecture Stack

| Tier | Technology / AWS Service | Hostname / Endpoint | Port | Role |
| :--- | :--- | :--- | :--- | :--- |
| **Edge / DNS** | AWS Route 53 (Public Hosted Zone) | `devopsmoz.de` | 80 / 443 | Routes external user traffic to the Application Load Balancer |
| **Load Balancing** | AWS Application Load Balancer (ALB) | `vprofile-las-elb` | 80 → 8080 | Terminates HTTP traffic and health-checks EC2 application nodes |
| **Application Tier** | Apache Tomcat 10 + OpenJDK 17 (Ubuntu 24.04 ASG) | `vprofile-app01` (Auto Scaling) | 8080 | Serves the compiled Jakarta EE `.war` application |
| **Internal DNS** | AWS Route 53 (Private Hosted Zone) | `vprofile.pk` | DNS (53) | Decouples backend private IPs via internal FQDNs |
| **Database Tier** | MariaDB / MySQL on EC2 | `db01.vprofile.pk` | 3306 | Persistent relational storage for user accounts and application state |
| **Caching Tier** | Memcached on EC2 | `mc01.vprofile.pk` | 11211 | In-memory object and session caching |
| **Message Broker** | RabbitMQ on EC2 | `rmq01.vprofile.pk` | 5672 | Asynchronous message queuing between application workers |
| **Artifact Storage** | Amazon S3 | `vprofile-las-artifacts2180` | HTTPS | Stores compiled `.war` build artifacts for EC2 bootstrapping |

---

## Key Implementation Highlights

1. **Jakarta EE Migration (Tomcat 10 Compatibility):**
   - Migrated the legacy Java EE (`javax.*`) `vprofile-v2.war` artifact using the Apache Tomcat Jakarta EE Migration Tool (`jakartaee-migration-1.0.8-shaded.jar`) so it runs cleanly on Tomcat 10 and OpenJDK 17 on Ubuntu 24.04[cite: 10].
2. **Private Service Discovery via Route 53:**
   - Configured a Route 53 Private Hosted Zone (`vprofile.pk`) mapping `db01.vprofile.pk`, `mc01.vprofile.pk`, and `rmq01.vprofile.pk` to backend private EC2 IPs so backend instances can be replaced without recompiling application code[cite: 10].
3. **Least-Privilege Security Group Chaining:**
   - **ALB Security Group:** Allows inbound HTTP (`80`) from `0.0.0.0/0`.
   - **App Security Group:** Allows inbound `8080` strictly from the ALB Security Group.
   - **Backend Security Group:** Allows inbound `3306` (MySQL), `11211` (Memcached), and `5672` (RabbitMQ) strictly from the App Security Group.
4. **Golden AMI & Auto Scaling:**
   - Baked a verified Golden AMI from the configured Tomcat 10 application server and attached it to an EC2 Launch Template + Auto Scaling Group behind the ALB target group[cite: 10].

---

## Engineering Troubleshooting & Root Cause Analysis (Post-Mortem)

### Incident 1: Silent Login Failures ("User Not Found") & `UnknownHostException`
- **Symptom:** The web UI loaded over the ALB, but login attempts failed with a generic `User Not Found` error, and `catalina.out` logged repeated `Communications link failure` / `UnknownHostException: rmq01` exceptions[cite: 10].
- **Root Cause:** Inspecting the deployed archive (`unzip -p ROOT.war WEB-INF/classes/application.properties`) revealed that `application.properties` had been compiled with unqualified short hostnames (`db01`, `mc01`, `rmq01`) rather than the Route 53 private FQDNs (`db01.vprofile.pk`, `mc01.vprofile.pk`, `rmq01.vprofile.pk`)[cite: 10].
- **Resolution:** Updated `src/main/resources/application.properties` with full `.vprofile.pk` FQDNs, rebuilt the artifact (`mvn clean install -DskipTests`), verified the compiled properties inside the `.war`, uploaded to S3, and re-migrated onto Tomcat 10[cite: 10].

### Incident 2: Auto Scaling Group Health Check Timeouts
- **Symptom:** Newly launched ASG instances failed ALB target group health checks (`Request timed out`) after scaling events[cite: 10].
- **Root Cause:** The Launch Template pointed to an older AMI snapshot captured before the FQDN `.war` patch and `tomcat10` service enablement[cite: 10].
- **Resolution:** Verified `curl -I http://localhost:8080/` returned `HTTP/1.1 200`, enabled `tomcat10` on boot (`systemctl enable tomcat10`), captured a new Golden AMI, updated the Launch Template default version, and triggered an ASG Instance Refresh[cite: 10].

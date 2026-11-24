# Runbook: Multi-Tier Web Application Deployment on GCP

Step-by-step execution, DNS/SSL verification, resource audit, and cost-safe teardown guide for the automated `vProfile` deployment on Google Cloud Platform (`us-central1`)[cite: 16, 20, 21].

---

## Prerequisites

* GCP project with billing enabled (e.g., `pjkt-vprofile`) and **Cloud Shell** (or local `gcloud` CLI authenticated)[cite: 20, 23].
* Custom domain managed at a registrar (e.g., GoDaddy / Cloudflare) for CNAME SSL verification and `A` record routing[cite: 16, 17].
* SSH key pair generated locally (`ssh-keygen -t ed25519`)[cite: 23].

---

## Step 1: Configure Script Variables (`scripts/`)

Before running any script, open the **Student Configuration Section** at the top of `01-vpc.sh`, `02-backend.sh`, `03-frontend-1.sh`, and `04-frontend-2.sh` and set your environment values:

```bash
PROJECT_ID="<YOUR_GCP_PROJECT_ID>"
REGION="us-central1"
ZONE="${REGION}-a"
DOMAIN="<YOUR_DOMAIN>"                 # e.g., devopsmoaz.de
SUBDOMAIN="vprogcp"                    # Target URL: vprogcp.<YOUR_DOMAIN>
MY_IP="<YOUR_PUBLIC_IP>/32"
SSH_KEY="<YOUR_SSH_PUBLIC_KEY>"
DB_PASSWORD="<YOUR_DB_PASSWORD>"
```

---

## Step 2: Build VPC, Subnets, Cloud NAT, Firewalls & Bastion (`01-vpc.sh`)

Run `01-vpc.sh` in Google Cloud Shell:

```bash
chmod +x scripts/01-vpc.sh
./scripts/01-vpc.sh
```

* **What this provisions (Steps 1–8):**
  * Enables required APIs (`compute`, `dns`, `sqladmin`, `memcache`, `certificatemanager`, `servicenetworking`)[cite: 21].
  * Creates custom VPC `vprofile-vpc` with 2 public subnets (`172.20.1.0/24`, `172.20.2.0/24`) and 2 private subnets (`172.20.3.0/24`, `172.20.4.0/24`)[cite: 21].
  * Creates Cloud Router (`vprofile-router`) and Cloud NAT (`vprofile-nat`) so private-subnet VMs can reach the internet outbound[cite: 21].
  * Configures 3 firewall rules: `allow-ssh-internet` (TCP `22` → `bastion`), `allow-ssh-bastion` (TCP `22` `bastion` → `app`), and `allow-lb-to-app` (TCP `8080` from GCP LB ranges `130.211.0.0/22,35.191.0.0/16` → `app`)[cite: 21].
  * Launches the Ubuntu 24.04 `bastion` VM in `public-01`[cite: 21].

---

## Step 3: Provision Private Cloud SQL & Memorystore (`02-backend.sh`)

Run `02-backend.sh` to peer with Google-managed services and launch private backend tiers:

```bash
chmod +x scripts/02-backend.sh
./scripts/02-backend.sh
```

* **What this provisions (Steps 9–13):**
  * Allocates `google-psa-range` (`/16`) and connects Private Service Access peering (`servicenetworking.googleapis.com`)[cite: 19].
  * Provisions private Cloud SQL MySQL 8.0 (`vprofile-db`, `--no-assign-ip`), creates the `accounts` database, and sets the root password[cite: 19].
  * Provisions private Memorystore for Memcached (`vprofile-memcache`)[cite: 19].
* **Seed the `accounts` Schema via Bastion:**
  * SSH into the `bastion` VM (using its external IP), install `mysql-client`, and import `db_backup.sql` into Cloud SQL's private IP (`$db01IP`)[cite: 19]:

  ```bash
  ssh -i ~/.ssh/<YOUR_PRIVATE_KEY> devops@<BASTION_PUBLIC_IP>
  sudo apt update && sudo apt install -y mysql-client
  wget [https://raw.githubusercontent.com/hkhcoder/vprofile-project/refs/heads/gcp/src/main/resources/db_backup.sql](https://raw.githubusercontent.com/hkhcoder/vprofile-project/refs/heads/gcp/src/main/resources/db_backup.sql)
  mysql -h <CLOUD_SQL_PRIVATE_IP> -u root -p accounts < db_backup.sql
  mysql -h <CLOUD_SQL_PRIVATE_IP> -u root -p accounts -e "SHOW TABLES;"
  ```

---

## Step 4: Configure Private DNS, Golden Image & HTTP Load Balancer (`03-frontend-1.sh`)

Run `03-frontend-1.sh`:

```bash
chmod +x scripts/03-frontend-1.sh
./scripts/03-frontend-1.sh
```

* **What this provisions (Steps 14–31):**
  * Creates Private DNS zone `vprofile.internal` (`vprofile-private`) with `A` records for `vprodb.vprofile.internal` and `vpromc.vprofile.internal`[cite: 16, 23].
  * Launches temporary private VM `vprofile-golden` (`--no-address`), builds `vprofile-v2.war` with Maven, deploys it to Tomcat 10 (`ROOT.war`), captures disk snapshot `vprofile-snapshot` → custom image `vprofile-image`, and deletes `vprofile-golden`[cite: 16].
  * Creates Instance Template `vprofile-template` (`e2-micro`), launches Managed Instance Group `vprofile-mig` (autoscaled `2`–`4` replicas at 60% CPU), attaches Global HTTP Health Check (`:8080 /`), Backend Service, URL Map, HTTP Proxy, and Global Static IP (`vprofile-lb-ip`)[cite: 16].
  * Generates DNS authorization `auth-vprogcp` and prints the CNAME validation record[cite: 16].
* **Registrar Action:** Add the printed CNAME record in your domain DNS panel so Certificate Manager can validate domain ownership[cite: 16].

---

## Step 5: Provision Wildcard SSL & HTTPS Load Balancer (`04-frontend-2.sh`)

Once the CNAME record is added at your registrar, run `04-frontend-2.sh`:

```bash
chmod +x scripts/04-frontend-2.sh
./scripts/04-frontend-2.sh
```

* **What this provisions (Steps 32–36):**
  * Creates Google-managed wildcard certificate `cert-vprogcp` (`*.<YOUR_DOMAIN>`), Certificate Map `map-vprogcp`, Target HTTPS Proxy `vprofile-https-proxy`, and Global HTTPS Forwarding Rule on port `443` bound to `vprofile-lb-ip`[cite: 17].
* **Registrar Action:** Point an `A` record (`vprogcp.<YOUR_DOMAIN>`) to the printed `LB_IP_ADDR` and open `https://vprogcp.<YOUR_DOMAIN>/` (log in with `admin_vp` / `admin_vp`)[cite: 17, 23].

---

## Step 6: Resource Audit & Cost-Safe Teardown (`list.sh` & `rollback.sh`)

1. **Tear down all resources in reverse dependency order:**

   ```bash
   chmod +x scripts/rollback.sh
   ./scripts/rollback.sh
   ```

   *(Deletes HTTPS/HTTP forwarding rules, proxies, URL map, backend service, health check, static IP, MIG, template, custom image, snapshot, private DNS records/zone, Memorystore, Cloud SQL, Bastion, firewall rules, Cloud NAT/Router, subnets, PSA range, and SSL certificate resources.)*

2. **Verify zero billable resources remain:**

   ```bash
   chmod +x scripts/list.sh
   ./scripts/list.sh
   ```

   * **Expected verification:** Every section for Load Balancers, Static IPs, Compute Engine VMs/MIGs/Images/Snapshots/Disks, Cloud SQL, Memcached, Cloud NAT/Routers, and Certificate Manager returns `Listed 0 items.` (only the empty `vprofile-vpc` and inactive `servicenetworking.googleapis.com` peering remain at `$0.00/hr`)[cite: 23].
# Step-by-Step Build Guide — Re-Architecting vProfile on AWS (Managed PaaS)

## The Game Plan (Exact Build Order)
Before opening the AWS Console, here is the exact order we build things and **why**:
1. **Key Pair & Backend Security Groups:** Create our SSH key and firewalls for RDS, ElastiCache, and Amazon MQ first.
2. **Managed Backend Services (RDS, ElastiCache, Amazon MQ):** Launch the managed database, cache, and message broker first so we have their endpoints ready.
3. **AWS Elastic Beanstalk Environment:** Let Elastic Beanstalk automatically create our app servers, Load Balancer, and Auto Scaling Group.
4. **Connect Security Groups:** Allow Elastic Beanstalk's instances to talk to RDS, ElastiCache, and Amazon MQ.
5. **Initialize the RDS Database:** Launch a temporary EC2 jump box to load our SQL tables (`db_backup.sql`) into Amazon RDS, then delete the jump box.
6. **Health Check & HTTPS on Load Balancer:** Point the Beanstalk health check to `/login` and add an HTTPS (Port 443) listener using our ACM SSL certificate.
7. **Build & Deploy the App:** Put the RDS, ElastiCache, and Amazon MQ endpoints into `application.properties`, build the `.war` file, and upload it to Elastic Beanstalk.
8. **CloudFront CDN & Domain:** Put Amazon CloudFront in front of Elastic Beanstalk and point `devopsmoaz.de` (in GoDaddy/Route 53) to CloudFront.

---

## Step 1: Create Key Pair & Backend Security Groups

### 1. Create the SSH Key Pair
* Open **AWS Console → EC2 → Key Pairs → Create key pair**.
* Name it **`vprofile-beanstalk-key`** (`.pem`) and download it so Elastic Beanstalk (and our temporary database setup box) can use it.

### 2. Create 3 Backend Security Groups (Default VPC)
Create one firewall for each managed backend service so we can control exactly who is allowed to connect:

* **Security Group 1: `vprofile-rds-sg` (For Amazon RDS MySQL)**
  * **Inbound:** Port **3306** (MySQL/Aurora) — we will attach Elastic Beanstalk's security group here in Step 4.

* **Security Group 2: `vprofile-elasticache-sg` (For Amazon ElastiCache)**
  * **Inbound:** Port **11211** (Custom TCP) — we will attach Elastic Beanstalk's security group here in Step 4.

* **Security Group 3: `vprofile-activemq-sg` (For Amazon MQ)**
  * **Inbound:** Port **61617** / **5672** (Custom TCP) — we will attach Elastic Beanstalk's security group here in Step 4.

---

## Step 2: Launch the 3 Managed Backend Services
* **Why we do this first:** Just like Project 3, we launch the database, cache, and message broker *before* our app servers so we have their endpoints ready for `application.properties`.

### 1. Amazon RDS (Managed MySQL Database)
1. Open **AWS Console → RDS → Databases → Create database**.
2. **Creation method:** Standard create | **Engine:** **MySQL** (Community).
3. **Templates:** **Free tier** (`db.t3.micro`).
4. **Settings:**
   * **DB instance identifier:** `vprofile-rds`
   * **Master username:** `admin`
   * **Master password:** `admin123`
5. **Connectivity:**
   * **VPC:** Default VPC | **Public access:** No.
   * **VPC security group:** Choose existing → select **`vprofile-rds-sg`**.
6. **Additional configuration:** Set **Initial database name** to `accounts`, then click **Create database**.

### 2. Amazon ElastiCache (Managed Memcached)
1. Open **AWS Console → ElastiCache → Memcached caches → Create Memcached cache**.
2. **Name:** `vprofile-cache` | **Node type:** `cache.t3.micro` | **Number of nodes:** `1`.
3. **Connectivity / Security:** Attach **`vprofile-elasticache-sg`** (Default VPC) and click **Create**.

### 3. Amazon MQ (Managed ActiveMQ Broker)
1. Open **AWS Console → Amazon MQ → Brokers → Create brokers**.
2. **Broker engine:** **ActiveMQ** | **Deployment mode:** Single-instance broker.
3. **Settings:**
   * **Broker name:** `vprofile-mq` | **Instance type:** `mq.t3.micro`.
   * **ActiveMQ Web Console access:** Username `admin` / Password `admin123456` (must be at least 12 characters).
   * **Security group:** Select existing → **`vprofile-activemq-sg`**, then click **Create broker**.

---

## Step 3: Create the AWS Elastic Beanstalk Environment
* **Why we do this:** Instead of manually configuring Tomcat, Nginx, a Load Balancer, and an Auto Scaling Group like in Project 3, Elastic Beanstalk builds and wires all of them automatically.
1. Open **AWS Console → Elastic Beanstalk → Create application**.
2. **Application name:** `vprofile-beanstalk-app`.
3. **Platform:** **Tomcat** (select **Tomcat 10 with Corretto 17** or matching Java/Tomcat platform).
4. **Application code:** Select **Sample application** for now (we will upload our real `.war` file in Step 7 once the database is initialized).
5. **Configure service access & networking (Click *Next* through the wizard):**
   * **EC2 key pair:** Select **`vprofile-beanstalk-key`**.
   * **Instance settings:** Select your Default VPC and check all subnets so the Load Balancer and instances span multiple Availability Zones.
   * **Capacity:** Set **Environment type** to **Load balanced** (Min `1`, Max `2` or `3`, instance type `t3.micro`).
6. Click **Submit** and wait ~5 minutes until the environment health turns **Green (Ok)**.

---

## Step 4: Connect Security Groups (Allow Traffic From Beanstalk)
* **Why we do this:** Elastic Beanstalk automatically created a security group for its EC2 instances (named `awseb-e-...-stack-AWSEBSecurityGroup-...`). Now we tell our 3 backend firewalls to trust that Beanstalk security group, and allow internal communication.
1. Go to **EC2 → Security Groups** and copy the **Security Group ID** of the Beanstalk instance security group (`AWSEBSecurityGroup`).
2. **Update `vprofile-rds-sg`:** Edit inbound rules → Port **`3306`** → Source: paste **`AWSEBSecurityGroup`**.
3. **Update `vprofile-elasticache-sg`:** Edit inbound rules → Port **`11211`** → Source: paste **`AWSEBSecurityGroup`**.
4. **Update `vprofile-activemq-sg`:** Edit inbound rules → Port **`61617`** (and `5672`) → Source: paste **`AWSEBSecurityGroup`**.
5. **Allow Internal Backend Traffic:** Ensure any multi-node backend group allows traffic from itself (its own Security Group ID) so internal health checks and cluster traffic are never blocked.

---

## Step 5: Initialize the RDS Database via a Temporary EC2 Box
* **Why we do this:** Because our Amazon RDS database is private (not accessible from the public internet), we launch a tiny temporary EC2 instance inside the same VPC, import our SQL tables (`db_backup.sql`), and then terminate that temporary instance.
1. **Launch a Temporary EC2 Instance:**
   * **Name:** `rds-init-temp` | **OS:** Amazon Linux 2023 | **Type:** `t3.micro` | **Key Pair:** `vprofile-beanstalk-key`.
   * **Security Group:** Allow SSH (`22`) from **My IP**, and temporarily allow Port **`3306`** from this instance's security group inside **`vprofile-rds-sg`**.
2. **SSH In & Import `db_backup.sql` into RDS:**
   ```bash
   sudo dnf update -y
   sudo dnf install -y mariadb105 git
   git clone -b main [https://github.com/hkhcoder/vprofile-project.git](https://github.com/hkhcoder/vprofile-project.git)
   mysql -h <YOUR-RDS-ENDPOINT> -u admin -padmin123 accounts < vprofile-project/src/main/resources/db_backup.sql
   ```
3. **Verify & Clean Up:**
   * Log in (`mysql -h <YOUR-RDS-ENDPOINT> -u admin -padmin123`) and run `USE accounts; SHOW TABLES;` to confirm the tables loaded.
   * **Terminate** `rds-init-temp` and remove its temporary rule from `vprofile-rds-sg`.

---

## Step 6: Update Beanstalk Health Check & Add HTTPS (Port 443)
* **Why we do this:** By default, Elastic Beanstalk checks `/` for HTTP `200`, which fails because vProfile redirects `/` to `/login` (`302`). We also attach our ACM SSL certificate to the Load Balancer so traffic is encrypted.
1. **Change Health Check Path to `/login`:**
   * Open **Elastic Beanstalk → Your Environment → Configuration → Instance traffic and scaling → Edit**.
   * Under **Processes → default → Edit**, change **Health check path** from `/` to **`/login`** and click **Apply**.
2. **Add HTTPS (Port 443) Listener to the Load Balancer:**
   * In the same **Instance traffic and scaling** section, under **Listeners**, click **Add listener**.
   * **Port:** `443` | **Protocol:** `HTTPS` | **SSL certificate:** Select your `devopsmoaz.de` / `*.devopsmoaz.de` certificate from **AWS Certificate Manager (ACM)**.
   * Save and click **Apply** so Elastic Beanstalk updates the Load Balancer.

---

## Step 7: Build the `.war` Artifact & Deploy to Elastic Beanstalk
* **Why we do this:** Now we point the Java source code to our managed RDS, ElastiCache, and Amazon MQ endpoints, compile the `.war` package, and upload it to Elastic Beanstalk.
1. **Update `application.properties` with Managed Endpoints:**
   * Open `src/main/resources/application.properties` and enter your endpoints from Step 2:
     * **RDS Endpoint:** `jdbc.url=jdbc:mysql://<YOUR-RDS-ENDPOINT>:3306/accounts?useUnicode=true&characterEncoding=UTF-8&zeroDateTimeBehavior=convertToNull` (username `admin`, password `admin123`)
     * **ElastiCache Endpoint:** `memcached.active.host=<YOUR-ELASTICACHE-ENDPOINT>` (Port `11211`)
     * **Amazon MQ Endpoint:** `rabbitmq.address=<YOUR-ACTIVEMQ-ENDPOINT>` (username `admin`, password `admin123456`)
2. **Compile the `.war` Package:**
   ```bash
   mvn clean install -DskipTests
   ```
3. **Upload & Deploy to Elastic Beanstalk:**
   * Open **Elastic Beanstalk → Your Environment → Upload and deploy**.
   * Choose `target/vprofile-v2.war`, give it a version label (e.g., `vprofile-paas-v1`), and click **Deploy**.
   * Wait until the environment health returns to **Green (Ok)** and test the Beanstalk URL in your browser.

---

## Step 8: Set Up CloudFront CDN & Point `devopsmoaz.de`
* **Why we do this:** CloudFront caches static assets at global edge locations for faster loading and terminates HTTPS cleanly in front of our Elastic Beanstalk Load Balancer.
1. **Create a CloudFront Distribution:**
   * Open **AWS Console → CloudFront → Create distribution**.
   * **Origin domain:** Select your **Elastic Beanstalk Load Balancer** from the dropdown.
   * **Protocol:** HTTPS only (or Match viewer).
   * **Viewer protocol policy:** **Redirect HTTP to HTTPS**.
   * **Alternate domain name (CNAME):** Add `devopsmoaz.de` (and `www.devopsmoaz.de`).
   * **Custom SSL certificate:** Select your **`devopsmoaz.de` ACM certificate** (`us-east-1`).
   * Click **Create distribution** and copy the **Distribution domain name** (e.g., `d1234abcd.cloudfront.net`).
2. **Update DNS Entry in GoDaddy (or Route 53):**
   * Log in to your DNS provider (**GoDaddy** or **Route 53**) for `devopsmoaz.de`.
   * Point your domain/subdomain **CNAME / Alias record** to your **CloudFront distribution domain name**.
3. **Final End-to-End Verification:**
   * Open **`https://devopsmoaz.de`** in your browser, confirm the green padlock (HTTPS), log in with `admin_vp` / `admin_vp`, and verify user data, caching, and messaging work end-to-end.
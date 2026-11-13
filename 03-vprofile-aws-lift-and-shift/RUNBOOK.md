# Step-by-Step Build Guide — vProfile on AWS (Lift & Shift) a multi-tier Java web application

## The Game Plan (Build Order)
Before opening the AWS Console, here is the exact sequence we follow and **why** each step comes in this order:
1. **Key Pair & Security Groups:** Create our SSH key and 3 firewalls first so every server we launch is locked down from the very beginning.
2. **Backend Servers (`db01`, `mc01`, `rmq01`):** Launch the database, cache, and queue servers *first* so we have their private IP addresses ready.
3. **Private DNS (Route 53):** Map those 3 private IPs to clean internal domain names (`db01.vprofile.pk`, `mc01.vprofile.pk`, `rmq01.vprofile.pk`).
4. **Build & Upload App (S3):** Compile the Java application into a `.war` package and store it in an S3 bucket.
5. **App Server (`vprofile-app01`):** Launch Tomcat, pull the `.war` package from S3, and verify the website works.
6. **Load Balancer & Domain:** Place an Application Load Balancer in front of the app server and point `devopsmoaz.de` to it.
7. **Golden AMI & Auto Scaling:** Save a snapshot (AMI) of the working app server so Auto Scaling can automatically create identical copies whenever needed.

---

## Step 1: Create Key Pair & 3 Security Groups (Firewalls)

### 1. Create the SSH Key Pair
* Open **AWS Console → EC2 → Key Pairs → Create key pair**.
* Name it **`vprofile-prod-key`** (`.pem`) and download it so you can connect to your Linux instances via SSH.

### 2. Create 3 Security Groups (Using Your Default VPC)
Instead of opening every port to the entire internet, each layer acts like a security checkpoint—it **only** accepts traffic from the layer directly in front of it:

* **Firewall 1: `vprofile-ELB-SG` (Attached to the Load Balancer)**
  * **Inbound:** Port **80** (HTTP) and Port **443** (HTTPS) from **Anywhere (`0.0.0.0/0`)**.
  * **Why:** Public users on the internet need to reach the front door (your Load Balancer).

* **Firewall 2: `vprofile-app-SG` (Attached to the Tomcat App Server)**
  * **Inbound:** Port **8080** (Custom TCP) from **`vprofile-ELB-SG`**, plus Port **22** (SSH) from **My IP**.
  * **Why:** Users should never bypass the Load Balancer to hit Tomcat directly—only the Load Balancer is allowed to talk to port 8080.

* **Firewall 3: `vprofile-backend-SG` (Attached to DB, Memcached & RabbitMQ)**
  * **Inbound:**
    * Port **3306** (MySQL) from **`vprofile-app-SG`**
    * Port **11211** (Memcached) from **`vprofile-app-SG`**
    * Port **5672** (RabbitMQ) from **`vprofile-app-SG`**
    * Port **22** (SSH) from **My IP**
  * **Why:** Only the Tomcat App Server needs to communicate with the database, cache, and queue—never the public internet.

---

## Step 2: Launch the 3 Backend Servers (Database, Cache & Queue)

We launch these 3 servers **before** the App Server because we need their private IP addresses first.
* **Common Settings for All 3 Instances:**
  * **OS / AMI:** Amazon Linux 2023
  * **Instance Type:** `t3.micro`
  * **Key Pair:** `vprofile-prod-key`
  * **Security Group:** `vprofile-backend-SG`
  * **Where to paste the scripts below:** Expand **Advanced details → User data** at the bottom of the launch page.

### 1. Database Server (`vprofile-db01`)
* **What it does:** Installs MariaDB, creates the `accounts` database and `admin` user, and imports the initial user table (`admin_vp`).
* **User Data Script:**
```bash
#!/bin/bash
dnf update -y
dnf install -y mariadb105-server git
systemctl enable --now mariadb

git clone -b main [https://github.com/hkhcoder/vprofile-project.git](https://github.com/hkhcoder/vprofile-project.git) /tmp/vprofile-project
mysql -e "CREATE DATABASE IF NOT EXISTS accounts;"
mysql -e "CREATE USER IF NOT EXISTS 'admin'@'%' IDENTIFIED BY 'admin123';"
mysql -e "GRANT ALL PRIVILEGES ON accounts.* TO 'admin'@'%'; FLUSH PRIVILEGES;"
mysql accounts < /tmp/vprofile-project/src/main/resources/db_backup.sql
```

### 2. Cache Server (`vprofile-mc01`)
* **What it does:** Installs Memcached and configures it to accept network connections from the app server on port `11211`.
* **User Data Script:**
```bash
#!/bin/bash
dnf install -y memcached
sed -i 's/127.0.0.1/0.0.0.0/g' /etc/sysconfig/memcached
systemctl enable --now memcached
```

### 3. Message Queue Server (`vprofile-rmq01`)
* **What it does:** Installs RabbitMQ, enables remote client connections (`loopback_users`), and creates the `test` user with full permissions on port `5672`.
* **User Data Script:**
```bash
#!/bin/bash
dnf install -y rabbitmq-server
systemctl enable --now rabbitmq-server
echo '[{rabbit, [{loopback_users, []}]}].' > /etc/rabbitmq/rabbitmq.config
systemctl restart rabbitmq-server
rabbitmqctl add_user test test
rabbitmqctl set_user_tags test administrator
rabbitmqctl set_permissions -p / test ".*" ".*" ".*"
```

---

## Step 3: Map Backend IPs in Route 53 (Private DNS)
* **Why we do this:** If a backend server restarts and gets a new IP address, we only update the DNS record here instead of rebuilding the application.
1. Open **AWS Console → Route 53 → Hosted zones → Create hosted zone**.
2. Set **Domain name** to `vprofile.pk` and **Type** to **Private hosted zone** (attached to your Default VPC).
3. Create 3 **A records** pointing to each backend instance's **Private IPv4 address**:
   * `db01.vprofile.pk` → Private IP of `vprofile-db01`
   * `mc01.vprofile.pk` → Private IP of `vprofile-mc01`
   * `rmq01.vprofile.pk` → Private IP of `vprofile-rmq01`

---

## Step 4: Build the Application (`.war`) & Upload to S3
* **Why we do this:** Instead of compiling Java source code directly on our production web server, we package the app into a single `.war` file first and upload it to an **S3 bucket** (`vprofile-las-artifacts2180`) so our app server can pull it cleanly.
1. **Verify Backend Names in `application.properties`:**
   * Open `src/main/resources/application.properties` in the `vprofile-project` source code.
   * Confirm the database, cache, and queue addresses use the **full private Route 53 names** from Step 3 (not short hostnames):
     * `jdbc.url=jdbc:mysql://db01.vprofile.pk:3306/accounts?useUnicode=true&characterEncoding=UTF-8&zeroDateTimeBehavior=convertToNull`
     * `memcached.active.host=mc01.vprofile.pk`
     * `rabbitmq.address=rmq01.vprofile.pk`
2. **Build & Upload to S3:**
   * Run Maven to compile the `.war` package and upload it to your S3 bucket:
   ```bash
   mvn clean install -DskipTests
   aws s3 cp target/vprofile-v2.war s3://vprofile-las-artifacts2180/vprofile-v2.war
   ```

---

## Step 5: Launch & Configure the App Server (`vprofile-app01`)
* **Why we do this:** Now that the backend servers and S3 artifact are ready, we launch our Ubuntu web server, install **Java 17** and **Tomcat 10**, convert the `.war` file so Tomcat 10 can run it, and verify the website works before creating our Golden AMI.
1. **Launch the EC2 Instance:**
   * **Name:** `vprofile-app01`
   * **OS / AMI:** Ubuntu 24.04 LTS
   * **Instance Type:** `t3.micro`
   * **Key Pair:** `vprofile-prod-key`
   * **Security Group:** `vprofile-app-SG`
   * **User Data:** Leave empty (we configure it manually via SSH so we can verify everything before taking our Golden AMI).
2. **SSH In & Install Java 17 + Tomcat 10:**
   ```bash
   sudo apt update -y
   sudo apt install -y openjdk-17-jdk tomcat10 unzip curl awscli
   ```
3. **Add Java 17 Reflection Permissions for Tomcat 10:**
   * Java 17 blocks older Spring frameworks from inspecting internal classes unless we pass `--add-opens` flags:
   ```bash
   sudo mkdir -p /etc/systemd/system/tomcat10.service.d
   cat << 'EOF' | sudo tee /etc/systemd/system/tomcat10.service.d/override.conf
   [Service]
   Environment="JAVA_OPTS=-Djava.awt.headless=true --add-opens java.base/java.lang=ALL-UNNAMED --add-opens java.base/java.util=ALL-UNNAMED"
   EOF
   sudo systemctl daemon-reload
   ```
4. **Download the `.war` from S3, Migrate It & Deploy to Tomcat:**
   * Tomcat 10 uses `jakarta.*` packages instead of `javax.*`, so we run the official Apache migration tool before placing `ROOT.war` into Tomcat's `webapps` directory:
   ```bash
   aws s3 cp s3://vprofile-las-artifacts2180/vprofile-v2.war /tmp/vprofile-v2.war
   curl -L -o /tmp/jakartaee-migration.jar [https://repo1.maven.org/maven2/org/apache/tomcat/jakartaee-migration/1.0.8/jakartaee-migration-1.0.8-shaded.jar](https://repo1.maven.org/maven2/org/apache/tomcat/jakartaee-migration/1.0.8/jakartaee-migration-1.0.8-shaded.jar)

   sudo rm -rf /var/lib/tomcat10/webapps/ROOT /var/lib/tomcat10/webapps/ROOT.war
   sudo java -jar /tmp/jakartaee-migration.jar /tmp/vprofile-v2.war /var/lib/tomcat10/webapps/ROOT.war
   sudo chown -R tomcat:tomcat /var/lib/tomcat10/webapps/
   sudo systemctl enable --now tomcat10
   ```
5. **Verify Before Scaling:**
   * Temporarily allow port `8080` from My IP on `vprofile-app-SG`, open `http://<APP01-PUBLIC-IP>:8080/` in your browser, log in with `admin_vp` / `admin_vp`, and remove the temporary port `8080` rule once confirmed.

---

## Step 6: Golden AMI, Load Balancer, Domain & Auto Scaling
* **Why we do this:** Instead of configuring servers by hand every time traffic grows or an instance fails, we snapshot our working `vprofile-app01` server into an **AMI** and let an **Application Load Balancer + Auto Scaling Group** manage the fleet behind `devopsmoaz.de`.
1. **Create the Golden AMI:**
   * In **EC2 → Instances**, select `vprofile-app01` → **Actions → Image and templates → Create image**.
   * Name it `vprofile-app-golden-ami` and wait until its status changes to **Available**.
2. **Create Target Group (`vprofile-las-tg`):**
   * **Target type:** Instances | **Protocol:** HTTP | **Port:** `8080` | **VPC:** Default VPC.
   * **Health check path:** `/` | **Success codes:** `200,302` (Tomcat redirects `/` to `/login`, which returns HTTP `302`).
3. **Create Application Load Balancer (`vprofile-las-elb`):**
   * **Scheme:** Internet-facing | **Network mapping:** Select all Availability Zones in your Default VPC.
   * **Security Group:** `vprofile-ELB-SG`.
   * **Listener:** HTTP Port `80` → Forward to **`vprofile-las-tg`**.
4. **Point Your Domain (`devopsmoaz.de`) to the Load Balancer:**
   * In **Route 53** (or GoDaddy DNS), create an **Alias A record** (or CNAME) pointing `devopsmoaz.de` to the **ALB DNS name**.
5. **Create Launch Template & Auto Scaling Group (`vprofile-las-ASG`):**
   * **Launch Template:** Choose `vprofile-app-golden-ami`, instance type `t3.micro`, key pair `vprofile-prod-key`, and security group `vprofile-app-SG`.
   * **Auto Scaling Group:** Attach the Launch Template, select all Availability Zones, attach to **`vprofile-las-tg`**, set **Health check type** to **ELB** with a **300-second grace period**, and set Desired/Min capacity to `1` (Max `2` or `3`).
   * Once the ASG target shows **Healthy**, terminate the original standalone `vprofile-app01` instance and open `http://devopsmoaz.de` to verify everything serves through Auto Scaling.
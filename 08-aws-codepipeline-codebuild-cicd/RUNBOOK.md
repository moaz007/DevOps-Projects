# Runbook: AWS CodePipeline & CodeBuild CI/CD Setup

Step-by-step build, verification, and teardown guide to reproduce the AWS-native CI/CD pipeline (`Bitbucket` → `CodePipeline` → `CodeBuild` → `Elastic Beanstalk` + `Amazon RDS`) from scratch[cite: 17].

---

## Prerequisites

* AWS account with IAM permissions for **Elastic Beanstalk**, **RDS**, **CodeBuild**, **CodePipeline**, **S3**, and **IAM** (region: `us-east-1`)[cite: 17].
* Bitbucket account with a repository created (e.g., `vpropapp`)[cite: 17].
* Local workstation with `git` installed.

---

## Step 1: Provision AWS Elastic Beanstalk (Tomcat PaaS Tier)

1. Open **AWS Console → Elastic Beanstalk → Create application** (`us-east-1`)[cite: 17].
2. **Step 1 — Configure environment:**
   * **Environment tier:** `Web server environment`[cite: 17]
   * **Application name:** `vprofile`[cite: 17]
   * **Environment name:** `Vprofile-prod1134`[cite: 17]
   * **Platform:** `Tomcat` → `Tomcat 10 with Corretto 21 running on 64bit Amazon Linux 2023`[cite: 17]
   * **Application code:** `Sample application`[cite: 17]
3. **Step 2 — Configure service access:**
   * **Service role:** `aws-elasticbeanstalk-service-role`[cite: 17]
   * **EC2 key pair:** Select your SSH key pair (e.g., `vprobeankey`)[cite: 17]
   * **EC2 instance profile:** `vprofile-bean-role` (with `AWSElasticBeanstalkWebTier`, `AWSElasticBeanstalkWorkerTier`, and `AWSElasticBeanstalkMulticontainerDocker` policies)[cite: 17]
4. **Step 3 — Set up networking, database, and tags:**
   * **VPC:** Default VPC | **Public IP address:** `Activated`[cite: 17]
   * **Instance subnets:** Select all available subnets[cite: 17]
5. **Step 4 — Configure instance traffic and scaling:**
   * **Environment type:** `Load balanced` | **Min / Max instances:** `2` / `4` (`t2.micro`)[cite: 17]
   * **Scaling trigger:** `NetworkOut` (Average, Bytes) — Upper `6000000` (+1), Lower `2000000` (-1)[cite: 17]
   * **Load balancer:** Public Application Load Balancer (ALB) across all subnets[cite: 17]
6. **Step 5 — Configure updates, monitoring, and logging:**
   * **Managed updates:** Activated (`Rolling`, Batch size `50%`)[cite: 17]
   * **Proxy server:** `nginx` | **JVM Heap (`Xms` / `Xmx`):** `256m` / `256m`[cite: 17]
7. Click **Submit** and wait until the environment health turns **Ok**[cite: 17].

---

## Step 2: Provision Amazon RDS & Seed the Database Schema

1. Open **AWS Console → RDS → Create database** (`us-east-1`):
   * **Creation method:** `Standard create` | **Engine:** `MySQL` (`Free tier`)
   * **DB instance identifier:** `vprodrds`[cite: 17]
   * **Master username:** `admin` | **Master password:** `<YOUR_RDS_PASSWORD>`[cite: 17]
   * **Initial database name** *(under Additional configuration)*: `accounts`[cite: 17]
2. **Security Group Rule:** Open the RDS Security Group inbound rules and allow **MySQL/Aurora (TCP `3306`)** from the **Elastic Beanstalk EC2 Security Group**[cite: 17].
3. **Seed the `accounts` Schema via SSH:**
   * SSH into one of the running Elastic Beanstalk EC2 instances[cite: 17]:

   ```bash
   ssh -i ~/.ssh/vprobeankey.pem ec2-user@<BEANSTALK_EC2_PUBLIC_IP>
   ```

   * Install the MariaDB/MySQL client, download `db_backup.sql` from the `vprofile-project` repository, import it into RDS, and verify the tables[cite: 17]:

   ```bash
   sudo dnf install -y mariadb105
   wget [https://raw.githubusercontent.com/hkhcoder/vprofile-project/aws-ci/src/main/resources/db_backup.sql](https://raw.githubusercontent.com/hkhcoder/vprofile-project/aws-ci/src/main/resources/db_backup.sql)
   mysql -h <YOUR_RDS_ENDPOINT> -u admin -p accounts < db_backup.sql
   mysql -h <YOUR_RDS_ENDPOINT> -u admin -p accounts -e "SHOW TABLES;"
   ```

   * **Expected output:** `role`, `user`, `user_role`[cite: 17].

---

## Step 3: Migrate Source Repository from GitHub to Bitbucket

1. Clone the upstream repository locally and check out the `aws-ci` branch[cite: 17]:

   ```bash
   git clone -b aws-ci [https://github.com/hkhcoder/vprofile-project.git](https://github.com/hkhcoder/vprofile-project.git)
   cd vprofile-project
   git fetch --tags
   ```

2. Replace the `origin` remote with your Bitbucket repository and push all branches and tags[cite: 17]:

   ```bash
   git remote remove origin
   git remote add origin https://<BITBUCKET_USERNAME>@bitbucket.org/<WORKSPACE>/vpropapp.git
   git push -u origin --all
   git push origin --tags
   ```

3. Verify in Bitbucket that `pom.xml`, `src/`, and `buildspec.yml` appear on the **`aws-ci`** branch[cite: 17].

---

## Step 4: Configure AWS CodeBuild

1. Open **AWS Console → CodeBuild → Create build project** (`us-east-1`):
   * **Project name:** `vproappcicdbymoaz`[cite: 17]
   * **Source provider:** `Bitbucket` → Connect via OAuth → Select repository (`vpropapp`) and branch (`aws-ci`)[cite: 17]
2. **Environment:**
   * **Environment image:** `Managed image` | **Operating system:** `Ubuntu` | **Runtime:** `Standard` | **Image:** `aws/codebuild/standard:7.0`[cite: 17]
   * **Service role:** `New service role`
3. **Buildspec:**
   * Select **Insert build commands** → **Switch to editor**, and paste the contents of `buildspec.yml` (replacing `<YOUR_RDS_ENDPOINT>`, `<YOUR_RDS_USERNAME>`, and `<YOUR_RDS_PASSWORD>` with your RDS values)[cite: 17].
4. **Artifacts & Logs:**
   * **Type:** `Amazon S3` (select or create an S3 artifact bucket) | **CloudWatch logs:** Enabled[cite: 17]
5. Click **Create build project** and run **Start build** once to confirm `pre_build` (`sed` + `mvn --version`), `build` (`mvn install`), and `post_build` (`mvn package`) succeed[cite: 17].

---

## Step 5: Wire End-to-End AWS CodePipeline

1. Open **AWS Console → CodePipeline → Create pipeline** (`us-east-1`):
   * **Pipeline name:** `vprocicdpipeline` | **Pipeline type:** `V2` | **Execution mode:** `Queued`[cite: 17]
   * **Service role:** `New service role`[cite: 17]
2. **Source Stage:**
   * **Source provider:** `Bitbucket` | **Connection:** Select your Bitbucket connection[cite: 17]
   * **Repository:** `vpropapp` | **Branch:** `aws-ci` | **Detect changes:** `true` | **Output artifact format:** `CODE_ZIP`[cite: 17]
3. **Build Stage:**
   * **Build provider:** `AWS CodeBuild` | **Project name:** `vproappcicdbymoaz`[cite: 17]
4. **Deploy Stage:**
   * **Deploy provider:** `AWS Elastic Beanstalk`[cite: 17]
   * **Application name:** `vprofile` | **Environment name:** `Vprofile-prod1134`[cite: 17]
5. Click **Create pipeline** and wait ~4–6 minutes for **Source → Build → Deploy** to turn green[cite: 17].

---

## Step 6: Verification & End-to-End CI/CD Test

1. **Verify Live Application & Database Connectivity:**
   * Open your Elastic Beanstalk environment URL (`http://<ENV_NAME>.us-east-1.elasticbeanstalk.com`)[cite: 17].
   * Log in with `admin_vp` / `admin_vp` to confirm Tomcat successfully queries the `accounts` database on RDS[cite: 17].
2. **Verify Automated `git push` Deployment:**
   * Edit a visible heading in `src/main/webapp/WEB-INF/views/login.jsp`, then commit and push to `aws-ci`[cite: 17]:

   ```bash
   git add src/main/webapp/WEB-INF/views/login.jsp
   git commit -m "Test automated AWS CodePipeline deployment"
   git push origin aws-ci
   ```

   * Confirm CodePipeline automatically detects the commit, rebuilds the `.war` artifact in CodeBuild, rolls out the update to Elastic Beanstalk, and displays the updated text on the live site[cite: 17].

---

## Step 7: Cost-Safe Teardown

Delete resources in reverse order once testing is complete so no ongoing AWS charges accrue[cite: 17]:

1. **CodePipeline & CodeBuild:** Delete `vprocicdpipeline` and `vproappcicdbymoaz` (idle pipelines/projects incur no cost, but deleting keeps the account clean).
2. **Elastic Beanstalk:** Open **Elastic Beanstalk → Environments → `Vprofile-prod1134` → Actions → Terminate environment** (automatically deletes the EC2 instances, ALB, Target Group, and Auto Scaling Group)[cite: 17].
3. **Amazon RDS:** Open **RDS → Databases → `vprodrds` → Actions → Delete** (uncheck *Create final snapshot* and *Retain automated backups*)[cite: 17].
4. **Amazon S3:** Empty and delete the CodePipeline/CodeBuild artifact S3 buckets[cite: 17].
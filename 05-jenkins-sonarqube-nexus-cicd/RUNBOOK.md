# Step-by-Step Build Guide — CI/CD Pipeline with Jenkins, SonarQube & Nexus

## The Game Plan (Exact Build Order)
Before opening the AWS Console, here is the exact sequence we follow and **why**:
1. **Key Pair & Security Groups:** Create our SSH key and firewall rules for Jenkins (`8080`), SonarQube (`9000`), and Nexus (`8081`).
2. **Launch 3 EC2 Servers:** Spin up dedicated instances for Jenkins, SonarQube, and Nexus so each service has enough RAM and CPU to run smoothly.
3. **Install Jenkins Plugins & Tools:** Install Maven, Java, and the required plugins (Pipeline, SonarQube Scanner, Nexus Artifact Uploader, GitHub Integration, Slack Notification).
4. **Configure SonarQube & Nexus:** Create a login token in SonarQube and a hosted Maven repository in Nexus.
5. **Connect Everything Inside Jenkins:** Store SonarQube tokens, Nexus credentials, and GitHub SSH keys inside Jenkins Credentials.
6. **Add the `Jenkinsfile` & GitHub Webhook:** Put the pipeline script in our GitHub repo and set up a webhook so every `git push` triggers a build automatically.

---

## Step 1: Create Key Pair & Security Groups (Firewalls)

### 1. Create the SSH Key Pair
* Open **AWS Console → EC2 → Key Pairs → Create key pair**.
* Name it **`vprofile-cicd-key`** (`.pem`) and download it so you can SSH into all 3 servers.

### 2. Create 3 Security Groups (Using Your Default VPC)
* **Security Group 1: `jenkins-sg`**
  * **Inbound:**
    * Port **22** (SSH) from **My IP**
    * Port **8080** (Jenkins Web UI) from **My IP** and **GitHub Webhooks** (`0.0.0.0/0` during webhook testing)

* **Security Group 2: `sonarqube-sg`**
  * **Inbound:**
    * Port **22** (SSH) from **My IP**
    * Port **9000** (SonarQube Web UI & Scanner) from **My IP** and **`jenkins-sg`**

* **Security Group 3: `nexus-sg`**
  * **Inbound:**
    * Port **22** (SSH) from **My IP**
    * Port **8081** (Nexus Web UI & Artifact Upload) from **My IP** and **`jenkins-sg`**

---

## Step 2: Launch & Install the 3 CI/CD Servers

### 1. Jenkins Server (`jenkins-server`)
* **Instance Settings:** Ubuntu 24.04 LTS | **`t3.medium`** (4 GB RAM so Maven + Jenkins don't crash) | Security Group: **`jenkins-sg`**.
* **SSH In & Install Java 17, Maven & Jenkins:**
  ```bash
  sudo apt update -y
  sudo apt install -y openjdk-17-jdk maven git curl unzip

  curl -fsSL [https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key](https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key) | sudo tee /usr/share/keyrings/jenkins-keyring.asc > /dev/null
  echo deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] [https://pkg.jenkins.io/debian-stable](https://pkg.jenkins.io/debian-stable) binary/ | sudo tee /etc/apt/sources.list.d/jenkins.list > /dev/null
  sudo apt update -y && sudo apt install -y jenkins
  sudo systemctl enable --now jenkins
  ```
* **Unlock Jenkins:** Open `http://<JENKINS-PUBLIC-IP>:8080`, paste the password from `sudo cat /var/lib/jenkins/secrets/initialAdminPassword`, and click **Install suggested plugins**.

### 2. SonarQube Server (`sonarqube-server`)
* **Instance Settings:** Ubuntu 24.04 LTS | **`t3.medium`** (4 GB RAM required for SonarQube + Elasticsearch) | **20 GB root volume** | Security Group: **`sonarqube-sg`**.
* **SSH In & Start SonarQube (via Docker or Zip):**
  ```bash
  sudo apt update -y && sudo apt install -y docker.io
  sudo systemctl enable --now docker
  sudo sysctl -w vm.max_map_count=262144
  sudo docker run -d --name sonarqube -p 9000:9000 sonarqube:lts-community
  ```
* **Verify:** Open `http://<SONARQUBE-PUBLIC-IP>:9000` (default login: `admin` / `admin`, then set a new password).

### 3. Sonatype Nexus Server (`nexus-server`)
* **Instance Settings:** Ubuntu 24.04 LTS | **`t3.medium`** | **20 GB root volume** | Security Group: **`nexus-sg`**.
* **SSH In & Start Nexus:**
  ```bash
  sudo apt update -y && sudo apt install -y docker.io
  sudo systemctl enable --now docker
  sudo mkdir -p /opt/nexus-data && sudo chown -R 200:200 /opt/nexus-data
  sudo docker run -d --name nexus -p 8081:8081 -v /opt/nexus-data:/nexus-data sonatype/nexus3
  ```
* **Unlock Nexus:** Open `http://<NEXUS-PUBLIC-IP>:8081`, log in as `admin` using the password from `sudo cat /opt/nexus-data/admin.password`, and finish the setup wizard.

---

## Step 3: Install Required Jenkins Plugins & Configure Tools
* **Why we do this:** Out of the box, Jenkins only runs basic shell scripts. Plugins teach Jenkins how to talk to SonarQube, upload `.war` files to Nexus, read `pom.xml` versions, and post alerts to Slack.

1. **Install Plugins (`Manage Jenkins → Plugins → Available plugins`):**
   * Search for, check, and install all of the following without restarting until the end:
     * **Pipeline** & **Pipeline Utility Steps** (lets Jenkins read `pom.xml` version numbers)
     * **SonarQube Scanner** (connects Jenkins to SonarQube)
     * **Nexus Artifact Uploader** (pushes built `.war` files to Nexus)
     * **GitHub Integration** (receives push webhooks from GitHub)
     * **Slack Notification** (posts pass/fail build alerts to Slack)
     * **Build Timestamp** (adds clean timestamps to build logs)
2. **Register Maven & JDK (`Manage Jenkins → Tools`):**
   * **JDK installations:** Add JDK 17 (`JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64`).
   * **Maven installations:** Add Maven (`MAVEN_HOME=/usr/share/maven` or check *Install automatically*).

---

## Step 4: Configure SonarQube & Nexus (Tokens & Repositories)

### 1. Generate a SonarQube Token & Webhook
* **Why we do this:** Jenkins needs an API token to submit code scans, and SonarQube needs a webhook pointing back to Jenkins so the `Quality Gate` stage knows whether the code passed or failed.
1. Open SonarQube (`http://<SONARQUBE-PUBLIC-IP>:9000`) → **Administration → Security → Users → Tokens**.
2. Generate a token named **`jenkins-sonar-token`** and copy it immediately.
3. Go to **Administration → Configuration → Webhooks → Create**:
   * **Name:** `Jenkins`
   * **URL:** `http://<JENKINS-PUBLIC-IP>:8080/sonarqube-webhook/`

### 2. Create a Hosted Maven Repository in Nexus
* **Why we do this:** Nexus needs a dedicated storage bucket (repository) to receive our compiled `.war` files.
1. Open Nexus (`http://<NEXUS-PUBLIC-IP>:8081`) → **Settings (Gear Icon) → Repositories → Create repository**.
2. Select **`maven2 (hosted)`**:
   * **Name:** `vprofile-release`
   * **Version policy:** `Mixed` (or `Release`)
   * **Deployment policy:** `Allow redeploy`
3. Click **Create repository**.

---

## Step 5: Connect Everything Inside Jenkins

1. **Store Credentials (`Manage Jenkins → Credentials → System → Global credentials → Add Credentials`):**
   * **SonarQube Token:** Kind: **Secret text** | Secret: `<paste jenkins-sonar-token>` | ID: `sonar-token`
   * **Nexus Login:** Kind: **Username with password** | Username: `admin` | Password: `<your-nexus-password>` | ID: `nexus-login`
   * **GitHub SSH Key (for private repos):** Kind: **SSH Username with private key** | Username: `git` | Private Key: `<paste your private SSH key>` | ID: `github-ssh-key`
2. **Configure SonarQube Server (`Manage Jenkins → System → SonarQube servers`):**
   * Check **Environment variables**.
   * **Name:** `sonarserver`
   * **Server URL:** `http://<SONARQUBE-PRIVATE-IP>:9000`
   * **Server authentication token:** Select **`sonar-token`** and click **Save**.

---

## Step 6: Add the `Jenkinsfile` & Set Up the GitHub Webhook

1. **Create a `Jenkinsfile` in the Root of Your GitHub Repository:**
   * Commit this pipeline definition into your `vprofile-project` repository:
   ```groovy
   pipeline {
       agent any

       tools {
           maven "MAVEN3"
           jdk "JDK17"
       }

       environment {
           NEXUS_VERSION = "nexus3"
           NEXUS_PROTOCOL = "http"
           NEXUS_URL = "<NEXUS-PRIVATE-IP>:8081"
           NEXUS_REPOSITORY = "vprofile-release"
           NEXUS_CREDENTIAL_ID = "nexus-login"
       }

       stages {
           stage('Fetch Code') {
               steps {
                   git branch: 'main', url: '[https://github.com/hkhcoder/vprofile-project.git](https://github.com/hkhcoder/vprofile-project.git)'
               }
           }

           stage('Build') {
               steps {
                   sh 'mvn clean install -DskipTests'
               }
           }

           stage('Unit Test & Checkstyle') {
               steps {
                   sh 'mvn test'
                   sh 'mvn checkstyle:checkstyle'
               }
           }

           stage('SonarQube Code Analysis') {
               steps {
                   withSonarQubeEnv('sonarserver') {
                       sh '''
                       mvn sonar:sonar \
                         -Dsonar.projectKey=vprofile \
                         -Dsonar.projectName=vprofile \
                         -Dsonar.java.binaries=target/classes
                       '''
                   }
               }
           }

           stage('Quality Gate') {
               steps {
                   timeout(time: 10, unit: 'MINUTES') {
                       waitForQualityGate abortPipeline: true
                   }
               }
           }

           stage('Upload Artifact to Nexus') {
               steps {
                   script {
                       def pom = readMavenPom file: 'pom.xml'
                       nexusArtifactUploader(
                           nexusVersion: NEXUS_VERSION,
                           protocol: NEXUS_PROTOCOL,
                           nexusUrl: NEXUS_URL,
                           groupId: pom.groupId,
                           version: "${pom.version}-${BUILD_NUMBER}",
                           repository: NEXUS_REPOSITORY,
                           credentialsId: NEXUS_CREDENTIAL_ID,
                           artifacts: [
                               [artifactId: pom.artifactId,
                                classifier: '',
                                file: "target/${pom.artifactId}-${pom.version}.war",
                                type: 'war']
                           ]
                       )
                   }
               }
           }
       }

       post {
           always {
               echo 'Pipeline finished. Check SonarQube Quality Gate and Nexus repository.'
           }
       }
   }
   ```
2. **Create the Jenkins Pipeline Job:**
   * In Jenkins → **New Item** → Name: `vprofile-ci-pipeline` → Type: **Pipeline** → OK.
   * Under **Build Triggers**, check **GitHub hook trigger for GITScm polling**.
   * Under **Pipeline**, set **Definition** to **Pipeline script from SCM** → **SCM:** `Git` → paste your repository URL and branch `*/main` → **Script Path:** `Jenkinsfile` → Save.
3. **Add the Webhook in GitHub:**
   * Open your GitHub repository → **Settings → Webhooks → Add webhook**.
   * **Payload URL:** `http://<JENKINS-PUBLIC-IP>:8080/github-webhook/`
   * **Content type:** `application/json` | **Events:** Just the `push` event → **Add webhook**.
4. **Verify End-to-End:**
   * Push a small change to `main` (or click **Build Now** in Jenkins) and watch all 6 stages run automatically, check the Quality Gate in SonarQube, and confirm the `.war` artifact appears inside Nexus under **`vprofile-release`**.
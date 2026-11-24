## Moaz Amin's DevOps Projects

This repository is where I keep all the hands-on DevOps and cloud projects I have built, broken, and fixed along my learning journey. Every folder has the config files along with a `README.md` explaining how things fit together and a `RUNBOOK.md` with the commands I used to set it up.

---

### My Projects

1. **[Project 1 — Flask App with Nginx & Docker Compose](01-flask-nginx-docker-compose/)**
   A simple python Flask app with Nginix reverse proxy using Docker Compose which runs over Docker bridge network so Nginx routes it's traffic once Flask app passes it's health check.
   

2. **[Project 2 — Automated CI/CD with GitHub Actions & GHCR](02-flask-github-actions-ghcr-cicd/)**
   In this project I set up a GitHub Actions workflow that runs `pytest` on every push, builds the Docker image, and pushes tagged images straight to GitHub Container Registry.

3. **[Project 3 — Multi-Tier Web App on AWS (Lift & Shift)](03-vprofile-aws-lift-and-shift/)**
   Here I deployed the multi-tier vProfile Java stack manually on AWS EC2 instances (Tomcat, MariaDB, Memcached, RabbitMQ) behind an Application Load Balancer, Auto Scaling Group, Golden AMIs, and a Route 53 private hosted zone.

4. **[Project 4 — Refactoring vProfile to Managed AWS Services](04-vprofile-aws-paas-refactoring/)**
   In this project I refactored the same vProfile application using managed AWS PaaS services instead of self-hosted EC2 servers—moving onto Elastic Beanstalk, RDS, ElastiCache, Amazon MQ, S3, and CloudFront.

5. **[Project 5 — CI/CD Pipeline with Jenkins, SonarQube & Nexus](05-jenkins-sonarqube-nexus-cicd/)**
   Here I built a multi-stage Jenkins pipeline that pulls Java code, runs Maven builds and unit tests, checks code quality with SonarQube quality gates, and uploads versioned artifacts.

6. **[Project 6 — AWS Web Infrastructure with Terraform](06-terraform-aws-web-infra/)**
   This project is my hands on guide for learning Terraform and replacing AWS Console Clicks with Terraform code, starting from hardcoded EC2 resources and moving to variables, SSH provisioners, outputs, and an S3 remote state backend. 

7. **[Project 7 — Server Configuration & AWS Provisioning with Ansible](07-ansible-multi-os-config-mgmt/)**
   Here I used Ansible to configure mixed servers agentlessly over SSH—moving from a raw playbook to reusable Ansible Roles, and EC2 provisioning through playbook.

8. **[Project 8 — AWS CI/CD Pipeline with CodePipeline & CodeBuild](08-aws-codepipeline-codebuild-cicd/)**
   In this project I built an AWS-native CI/CD pipeline connecting Bitbucket to AWS CodePipeline and CodeBuild to inject RDS credentials at build time, package the vProfile `.war` artifact with Maven, and deploy automatically to Elastic Beanstalk.

9. **[Project 9 — Multi-Tier Web App Deployment on Google Cloud (GCP)](09-gcp-multi-tier-vprofile-deployment/)**
   Here I automated the multi-tier vProfile deployment on GCP using `gcloud` shell scripts—setting up a custom VPC with Cloud NAT, Private Service Access for Cloud SQL and Memorystore, internal Cloud DNS, a Golden Image Managed Instance Group, and a Global HTTPS Load Balancer with wildcard SSL.
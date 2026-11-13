# Project 6 — Automated AWS Web Infrastructure with Terraform (IaC)

## What This Project Does
In earlier projects, I created EC2 instances, security groups, and key pairs manually through the AWS Console ("ClickOps"). In **Project 6**, I replaced manual clicking with **Terraform (Infrastructure as Code)** to automatically provision an AWS EC2 web server, configure its firewall rules, bootstrap an Apache web application via SSH provisioners, export runtime IP outputs locally, and store the shared state file remotely in **Amazon S3**.

> **Want to rebuild this from scratch?** Follow the step-by-step commands in (RUNBOOK.md).

---

## How the Infrastructure & State Flow (Architecture Flowchart)

```text
[ Local Workstation: terraform apply ]
          │
          ├───────────────────────────────────────────┐
          ▼                                           ▼
[ AWS Cloud (us-east-1) ]                   [ Amazon S3 Bucket ]
 ├── aws_key_pair (SSH Key)                  └── terraform.tfstate
 ├── aws_security_group (Ports 22 & 80)          (Remote Team State)
 └── aws_instance (Ubuntu / Amazon Linux)
          │
          ├──▶ file & remote-exec provisioners (uploads & runs web.sh)
          └──▶ local-exec provisioner (saves Private IP to local file)
```

---

## What Is Included in This Folder
1. **`provider.tf` & `vars.tf`:** Configures the AWS provider (`us-east-1`) and parameterizes regions, availability zones, instance types, and AMI IDs so nothing is hardcoded.
2. **`security_group.tf` & `keypair.tf`:** Creates the SSH key pair and restricts inbound traffic to HTTP (`80`) and SSH (`22`).
3. **`instance.tf` & `web.sh`:** Provisions the EC2 web server, uploads the `web.sh` deployment script, installs Apache, and deploys the live web template automatically.
4. **`outputs.tf` & `backend.tf`:** Exports the server's public/private IPs and moves `terraform.tfstate` into an S3 remote backend for safe team collaboration.

---

## Biggest Problem I Solved (Debugging Story)
- **The Problem:** `terraform validate` passed with `Success! The configuration is valid.`, yet running `terraform plan` failed immediately with `Error: invalid AWS Region: var.region`.
- **How I Found It:** In `provider.tf` (and `instance.tf`), the variable reference was wrapped in double quotes (`region = "var.region"`), causing Terraform to read `"var.region"` as a literal text string rather than looking up the variable's value.
- **How I Fixed It:** Removed the quotation marks (`region = var.region` and `availability_zone = var.zone1`), re-ran `terraform plan`, and verified the clean execution plan before applying.
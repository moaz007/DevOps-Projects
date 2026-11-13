# Step-by-Step Build Guide — Automated AWS Web Infrastructure with Terraform

## The Game Plan (Exact Build Order)
Before running Terraform, here is the exact sequence we follow and **why**:
1. **Create Your Local SSH Key Pair:** Generate your local `dove-key` (private) and `dove-key.pub` (public) key pair so `keypair.tf` can register the public key in AWS and `instance.tf` can connect via SSH.
2. **Prepare the S3 Remote State Bucket:** Ensure the S3 bucket (`<Unique Bucket Name>`) exists in `us-east-1` so `backend.tf` can store `terraform.tfstate` remotely.
3. **Update Your IP in `security_group.tf`:** Replace `<YOUR_IP>/32` with your current public IPv4 address so SSH (port `22`) is locked down to your machine.
4. **Initialize & Validate (`terraform init` / `validate`):** Download the AWS provider, connect the S3 backend, and verify all `.tf` files have valid syntax.
5. **Plan & Apply (`terraform plan` / `apply`):** Provision the key pair, security group, and Ubuntu `t3.micro` EC2 instance, run `web.sh` automatically via `file` + `remote-exec` provisioners, save `private_ip.txt` locally via `local-exec`, and print `WebPublicIP` and `WebPrivateIP`.
6. **Verify & Clean Up (`terraform destroy`):** Open the live Apache website in your browser, then tear down all AWS resources cleanly.

---

## Step 1: Create Your Public & Private SSH Key Pair
* **Why we do this:** `keypair.tf` reads `dove-key.pub` to register your key in AWS, and `instance.tf` uses the private `dove-key` file over SSH to upload and execute `web.sh`.
* Create your `dove-key` (private key) and `dove-key.pub` (public key) inside `06-terraform-aws-web-infra/` (and make sure the private `dove-key` file stays listed in `.gitignore` so it is never pushed to GitHub).
* **Verify:** Confirm both `dove-key` and `dove-key.pub` exist in your working folder.

---

## Step 2: Prepare Your S3 Bucket & Security Group IP
1. **S3 Remote State Bucket (`backend.tf`):**
   * Confirm the S3 bucket **`<Unique Bucket Name>`** exists in **`us-east-1`** (or update the `bucket` name in `backend.tf` to match your bucket):
     ```bash
     aws s3 mb s3://terraformstate2180598 --region us-east-1
     ```
2. **Allow Your IP for SSH (`security_group.tf`):**
   * Open `security_group.tf` and replace `<YOUR_IP>/32` in `aws_vpc_security_group_ingress_rule.sshfromyIP` with your current public IP address so Terraform can SSH into the instance during `terraform apply`.

---

## Step 3: Initialize, Format & Validate Terraform
Run these commands inside `06-terraform-aws-web-infra/`:
```bash
terraform init
terraform fmt
terraform validate
```
* **Verify:** `terraform init` confirms `Successfully configured the backend "s3"!`, and `terraform validate` prints `Success! The configuration is valid.`

---

## Step 4: Preview & Provision the Infrastructure
1. **Review the Execution Plan:**
   ```bash
   terraform plan
   ```
   * **Verify:** Confirm Terraform plans to create the `aws_key_pair` (`dove-key`), `aws_security_group` (`dove-sg`) with its ingress/egress rules, `aws_instance` (`web`), and `aws_ec2_instance_state` (`web_state`).
2. **Apply the Configuration:**
   ```bash
   terraform apply -auto-approve
   ```
   * **What happens automatically during `apply`:**
     * **Networking & Compute:** Creates `dove-sg` (ports `22` and `80`) and launches the Ubuntu `t3.micro` instance in `us-east-1a` (`vars.tf`).
     * **`file` & `remote-exec` Provisioners (`instance.tf`):** Uploads `web.sh` to `/tmp/web.sh` and runs `sudo /tmp/web.sh` to install `apache2`, download `2117_infinite_loop.zip`, and deploy the website into `/var/www/html/`.
     * **`local-exec` Provisioner (`instance.tf`):** Appends the new instance's private IP to `private_ip.txt` on your local machine.
     * **Outputs (`outputs.tf`):** Prints `ami_id`, `WebPublicIP`, and `WebPrivateIP` in your terminal.

---

## Step 5: Verify the Live Website & Clean Up
1. **Test in Your Browser:**
   * Copy `WebPublicIP` from the Terraform output and open `http://<WebPublicIP>/` in your browser.
   * **Verify:** The Infinite Loop web template loads over HTTP (`200 OK`), and `private_ip.txt` on your computer contains the instance's private IP.
2. **Destroy All Resources When Done:**
   * Tear down the EC2 instance, security group, and key pair so no idle AWS charges remain:
     ```bash
     terraform destroy -auto-approve
     ```
   * **Verify:** `Destroy complete!` appears in your terminal and the EC2 instance terminates in the AWS Console.
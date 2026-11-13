# Step-by-Step Build Guide — Multi-OS Server Configuration Management with Ansible

## The Game Plan (Exact Build Order)
Before running any playbooks, here is the exact sequence we follow and **why**:
1. **Prepare Control Node & Managed Nodes:** Set up passwordless SSH from the Ansible Control Node (`scriptbox`) to our target hosts (`web01`, `web02`, `db01`) so Ansible can push configurations without interactive password prompts.
2. **Verify Inventory & Ad-Hoc Connectivity (`ansible -m ping`):** Confirm `ansible.cfg` and `inventory` reach every host group (`websrvgrp`, `dbsrvgrp`).
3. **Stage 1 — Run the Raw Playbook (`01-raw-playbook-without-roles/`):** Execute the standalone `provisioning.yaml` to install packages, deploy Jinja2 NTP templates, and copy files across mixed RedHat and Ubuntu nodes.
4. **Stage 2 — Run the Refactored Role (`02-refactored-with-roles/`):** Execute the modular `post-install` Ansible Role (`tasks`, `templates`, `files`, `handlers`, `vars`, `defaults`) and verify idempotency.
5. **Bonus Stage — Provision AWS EC2 with Ansible (`03-aws-ec2-provisioning/`):** Use `test-aws.yml` with the `amazon.aws` collection to spin up an EC2 instance directly from an Ansible playbook.

---

## Step 1: Verify Control Node Setup & SSH Connectivity
* **Why we do this:** Ansible is agentless—it connects to target servers over standard SSH using the user and private key defined in `ansible.cfg` and `inventory`.
1. Ensure Ansible is installed on the control node:
   ```bash
   ansible --version
   ```
2. Update the target IP addresses and SSH key path in `inventory` (keeping your private `.pem` key outside the Git repository).
3. Test connectivity across all host groups:
   ```bash
   ansible all -i inventory -m ping
   ```
   * **Verify:** Every host (`web01`, `web02`, `db01`) returns `"ping": "pong"` in green.

---

## Step 2: Run Stage 1 — Raw Playbook Without Roles (`01-raw-playbook-without-roles/`)
* **Why we do this:** This stage keeps variables (`group_vars/`), templates (`templates/`), static files (`files/`), and tasks inside one flat `provisioning.yaml` file.
1. Move into the Stage 1 directory:
   ```bash
   cd 07-ansible-multi-os-config-mgmt/01-raw-playbook-without-roles
   ```
2. Run a syntax check first:
   ```bash
   ansible-playbook --syntax-check provisioning.yaml
   ```
3. Execute the playbook:
   ```bash
   ansible-playbook provisioning.yaml
   ```
   * **What happens automatically:**
     * Ansible gathers OS facts (`ansible_os_family`) from each node.
     * On **RedHat/CentOS** nodes, it installs `chrony`/`ntp` via `yum` and renders `templates/ntp_redhat.conf.j2`.
     * On **Debian/Ubuntu** nodes, it installs `ntp` via `apt` and renders `templates/ntp_debian.conf.j2`.
     * Copies `files/dev.txt` to the target nodes and restarts the NTP service only when configuration files change.

---

## Step 3: Run Stage 2 — Refactored Playbook With Roles (`02-refactored-with-roles/`)
* **Why we do this:** Refactoring into `roles/post-install/` separates tasks, handlers, templates, files, and variables into standard reusable directories so `provisioning.yaml` stays clean and shareable across teams.
1. Move into the Stage 2 directory:
   ```bash
   cd ../02-refactored-with-roles
   ```
2. Run the role-based playbook:
   ```bash
   ansible-playbook provisioning.yaml
   ```
3. **Verify Idempotency:**
   * Run `ansible-playbook provisioning.yaml` a second time.
   * **Verify:** All tasks report `ok` with **`changed=0`**, proving Ansible only applies changes when the server drifts from the desired state.

---

## Step 4: Bonus — Provisioning AWS EC2 Instances via Ansible (`03-aws-ec2-provisioning/`)
* **Why we do this:** In addition to configuring OS packages inside existing servers, Ansible can call AWS APIs via `amazon.aws.ec2_instance` to launch cloud instances directly from YAML.
1. Install the AWS collection and `boto3` on your control node:
   ```bash
   ansible-galaxy collection install amazon.aws
   pip install boto3 botocore
   ```
2. Move into `03-aws-ec2-provisioning/`, ensure your AWS credentials are configured (`aws configure`), and run:
   ```bash
   cd ../03-aws-ec2-provisioning
   ansible-playbook test-aws.yml
   ```
   * **Verify:** Confirm the new EC2 instance launches in your AWS Console (`us-east-1`), and terminate it once verified so you incur no ongoing charges.
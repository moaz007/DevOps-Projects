# Project 7 — Multi-OS Server Configuration Management with Ansible

## What This Project Does
In earlier projects, configuring Linux servers meant either running manual commands over SSH or maintaining OS-specific Bash scripts with `if/else` checks for RedHat vs. Ubuntu. In **Project 7**, I used **Ansible** to automate server configuration across mixed Linux distributions (**CentOS/RHEL** and **Ubuntu**) agentlessly over SSH—starting with a single-playbook setup (`01-raw-playbook-without-roles/`) and refactoring it into a reusable, modular **Ansible Role** (`02-refactored-with-roles/`).

> **Want to run this playbook from scratch?** Follow the step-by-step commands in [`RUNBOOK.md`](RUNBOOK.md).

---

## How Ansible Automates Mixed Operating Systems (Architecture Flowchart)

```text
[ Ansible Control Node ]
   ├── ansible.cfg & inventory (webservers + dbservers)
   └── provisioning.yaml ──▶ calls Role: roles/post-install
                                  ├── tasks/main.yml (OS-aware: RedHat vs Debian)
                                  ├── templates/*.j2 (ntp_redhat & ntp_debian)
                                  ├── files/dev.txt
                                  └── handlers/main.yml (restarts NTP only on change)
            │
            ├──────────────────────────────┐
            ▼  (SSH)                       ▼  (SSH)
[ CentOS / RHEL Nodes ]         [ Ubuntu / Debian Nodes ]
  - Installs chrony/ntp           - Installs ntp
  - Deploys ntp_redhat.conf.j2    - Deploys ntp_debian.conf.j2
  - Restarts ntpd/chronyd         - Restarts ntp
```

---

## Project Evolution Included in This Folder
1. **`01-raw-playbook-without-roles/` (Stage 1 — Single-Playbook Setup):**
   - Keeps all tasks, `group_vars/`, `files/`, and Jinja2 `templates/` inside one standalone `provisioning.yaml` file. Works well for a single setup, but tasks and templates are tied directly to one playbook.
2. **`02-refactored-with-roles/` (Stage 2 — Modular Ansible Role):**
   - Refactors the flat playbook into a reusable **`post-install` Role** (`tasks`, `handlers`, `templates`, `files`, `vars`, `defaults`) so `provisioning.yaml` becomes clean, readable, and shareable across multiple projects.

---

## Key Ansible Concepts Demonstrated
* **Inventory & `ansible.cfg`:** Centralizes host groups (`websrvgrp`, `dbsrvgrp`), SSH user settings, and privilege escalation (`become`) so playbooks run cleanly without long CLI flags.
* **Decision Making (`when` Conditionals & Facts):** Uses `ansible_os_family` (`RedHat` vs. `Debian`) gathered automatically by Ansible to run the right package manager (`yum`/`dnf` vs. `apt`) and service names without manual OS detection scripts.
* **Jinja2 Templates (`.j2`):** Dynamically renders OS-specific NTP configuration files (`ntp_redhat.conf.j2` and `ntp_debian.conf.j2`) using variables from `defaults/` and `vars/`.
* **Handlers (`notify`):** Ensures services (`ntpd` / `ntp`) only restart when a configuration template actually changes—keeping runs **idempotent**.
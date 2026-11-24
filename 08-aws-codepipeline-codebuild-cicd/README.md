# AWS-Native CI/CD Pipeline (CodePipeline, CodeBuild & Elastic Beanstalk)

An end-to-end automated CI/CD pipeline built with native AWS developer tools to compile, package, and deploy a multi-tier Java web application (`vProfile`) onto a managed PaaS environment backed by Amazon RDS.

---

## Architecture & Traffic Flow

```text
[ Developer: git push ]
          │
          ▼
[ Bitbucket Repository (aws-ci branch) ]
          │
          ▼  (Change Detection / Webhook)
┌─────────────────────────────────────────────────────────────────┐
│                        AWS CodePipeline                         │
│                                                                 │
│  1. Source (Bitbucket) ──► 2. Build (CodeBuild) ──► 3. Deploy   │
└─────────────────────────────────────────────────────────┬───────┘
                                                          │
                                                          ▼
                                            [ AWS Elastic Beanstalk ]
                                              (Tomcat 10 + ALB + ASG)
                                                          │
                                                          ▼  (TCP 3306)
                                                   [ Amazon RDS ]
                                                  (MySQL: accounts)
```

---

## Pipeline Evolution & Implementation Stages

* **Stage 1 — Managed Hosting & Database Tier (`Elastic Beanstalk` + `Amazon RDS`):** Provisioned a load-balanced Tomcat 10 (Corretto 21) environment on Elastic Beanstalk with Auto Scaling (2–4 `t2.micro` instances) alongside a standalone MySQL RDS instance (`accounts`) initialized with the application schema (`user`, `role`, `user_role`).
* **Stage 2 — Source Control Migration (`GitHub` → `Bitbucket`):** Cloned `vprofile-project`, checked out the `aws-ci` branch, fetched all tags, removed the GitHub origin, and migrated the repository to Bitbucket (`devopscicdmoaz/vpropapp`).
* **Stage 3 — Automated Build & Packaging (`AWS CodeBuild` + `buildspec.yml`):** Configured an Ubuntu `aws/codebuild/standard:7.0` build project driven by `buildspec.yml` to inject RDS connection properties into `application.properties` at build time, compile the Java source via Maven (`mvn install`), and package the deployable `target/vprofile-v2` artifact (`mvn package`).
* **Stage 4 — End-to-End Orchestration (`AWS CodePipeline`):** Connected Bitbucket (`aws-ci` branch) → AWS CodeBuild → Elastic Beanstalk rolling deployments into a single automated pipeline triggered on every `git push`.

---

## Key Concepts Demonstrated

* **AWS-Native CI/CD Orchestration:** Connecting external Git repositories (Bitbucket) to AWS CodePipeline, passing zipped source and build artifacts through S3 artifact buckets, and triggering rolling deployments with automatic rollback on Elastic Beanstalk.
* **Build-Time Configuration Injection:** Using `sed` in the `pre_build` phase of `buildspec.yml` to dynamically inject the RDS endpoint and credentials into `application.properties` rather than hardcoding live database endpoints in source control.
* **Stateless Application vs. Stateful Database Separation:** Decoupling persistent relational data into standalone Amazon RDS so stateless Elastic Beanstalk instances can be replaced or scaled cleanly during automated deployments.
* **YAML & Build Container Troubleshooting:**
  * Resolved `buildspec.yml` YAML parser errors caused by unquoted colons (`db01:3306`) in `sed` commands and misaligned `commands:` list indentation.
  * Fixed external `wget` connection timeouts to `archive.apache.org` inside the CodeBuild container by removing redundant Maven downloads and using the pre-installed Apache Maven toolchain in `aws/codebuild/standard:7.0`.
* **Cloud Cost Hygiene:** Verified end-to-end automated updates via `git commit` & `git push`, followed by full teardown of the Elastic Beanstalk environment, RDS instance, and S3 artifacts.

---

## Repository Contents

* **`README.md`** — Architecture flow, implementation stages, and key engineering concepts.
* **`buildspec.yml`** — Sanitized AWS CodeBuild specification for build-time RDS property injection and Maven packaging.
* **`RUNBOOK.md`** — Step-by-step console/CLI setup, database seeding, pipeline wiring, verification, and teardown guide.
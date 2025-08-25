# The Self-Defending Edge: A DevSecOps Masterpiece

[![CI/CD Status](https://github.com/actions/workflow_status.svg?workflow_name=Edge+Security+CI)](https://github.com/kennethkcox/Take_Home_Exercise-/actions)

This repository contains the source code and documentation for a production-grade, highly automated, and self-defending security platform on AWS. It serves as a blueprint for a modern DevSecOps platform, demonstrating advanced cloud engineering and application security patterns.

The goal of this project is not merely to deploy an application, but to surround it with a robust, intelligent, and scalable security posture that requires minimal human intervention for day-to-day threat response.

**For a deep-dive into the architecture, security principles, and threat model, please see the [DESIGN.md](DESIGN.md) document.**

---

## High-Level Architecture

The platform consists of three key interacting systems: The CI/CD Pipeline for automated deployment, the Edge Security Platform for layered defense, and the Automated Defense Loop for real-time threat response.

```mermaid
graph TD
    subgraph "GitHub"
        direction LR
        A[Developer] -->|git push| B(GitHub Repo);
        B -->|Pull Request| C{Edge CI Workflow};
        C -->|terraform plan| B;
        B -->|Merge to main| D{Edge CD Workflow};
    end

    subgraph "AWS Account"
        direction TB

        subgraph "CI/CD Pipeline"
            D --> E[Terraform Apply];
        end

        subgraph "Edge Security Platform"
            direction LR
            F[Internet] --> G(CloudFront);
            G --> H(Lambda@Edge);
            H --> I(AWS WAF);
            I --> J[Application Load Balancer];
        end

        subgraph "Application"
            J --> K(ECS Fargate);
            K --> L[Juice Shop Container];
        end

        subgraph "Automated Defense Loop"
            direction TB
            I -->|Logs| M(Kinesis Firehose);
            M --> N[S3 Bucket];
            N -->|Logs| O(CloudWatch Logs);
            O -->|Metric Filter| P(CloudWatch Alarm);
            P -->|Trigger| Q(SNS Topic);
            Q -->|Invoke| R{Auto-Block Lambda};
            R -->|UpdateIPSet| I;
        end
    end

    style C fill:#00A4EF,stroke:#333,stroke-width:2px
    style D fill:#00A4EF,stroke:#333,stroke-width:2px
    style R fill:#FF9900,stroke:#333,stroke-width:2px
    style H fill:#FF9900,stroke:#333,stroke-width:2px
```

---

## Core Features

### Automation & CI/CD
*   **Infrastructure as Code:** The entire infrastructure is defined declaratively using **Terraform**.
*   **Automated CI/CD:** Two distinct **GitHub Actions** workflows for Continuous Integration (on PRs) and Continuous Deployment (on merge to `main`).
*   **IaC Testing:** The CI pipeline includes automated unit tests for the Terraform code using **Terratest**.
*   **Security Scanning:** Static analysis of the IaC is performed with **tfsec**, and container images are scanned with **Trivy**.

### Edge & Application Security
*   **Layered WAF:** A multi-layered **AWS WAF** configuration using AWS managed rule sets, custom application-specific rules, and an IP set populated by threat intelligence.
*   **Edge-Enforced Security Headers:** A **Lambda@Edge** function automatically injects a strict Content-Security-Policy (CSP) and other security headers on all responses.
*   **Self-Defending WAF:** A real-time feedback loop connects WAF logs to a **Lambda function** via CloudWatch Alarms. When an attack pattern is detected, the attacker's IP is automatically added to a blocklist, typically within 60 seconds.

### Operational Tooling
*   **Rapid Mitigation Script:** A `push_block.py` script for any necessary manual interventions to block IPs or URI patterns.
*   **Smoke Tests:** A `smoke_test.py` script, integrated into the CD pipeline, to verify application health after every deployment.
*   **Log Analysis & KPIs:** A full logging pipeline from the WAF to S3 via Kinesis Firehose, with an **Athena** table for querying security KPIs.

---

## Getting Started

For a detailed, step-by-step walkthrough of how to fork, configure, and deploy this project for the first time, please see the:

**[➡️ Foolproof Deployment Guide](docs/FOOLPROOF_GUIDE.md)**

### Quick Summary

*   **Prerequisites:** You will need an AWS account and a GitHub account.
*   **Configuration:** You must add `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, and `INFRACOST_API_KEY` as secrets to your forked repository.
*   **Deployment:** The deployment is fully automated via a GitOps workflow. All changes are made through Pull Requests, which are automatically tested. Merging a PR to the `main` branch will trigger the Continuous Deployment workflow.

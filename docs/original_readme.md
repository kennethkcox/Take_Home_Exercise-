# The Self-Defending Edge: A DevSecOps Masterpiece

[![CI/CD Status](https://github.com/actions/workflow_status.svg?workflow_name=Edge+Security+CI)](https://github.com/kennethkcox/Take_Home_Exercise-/actions)

This repository contains the source code and documentation for a production-grade, highly automated, and self-defending security platform on AWS. It serves as a blueprint for a modern DevSecOps platform, demonstrating advanced cloud engineering and application security patterns.

The goal of this project is not merely to deploy an application, but to surround it with a robust, intelligent, and scalable security posture that requires minimal human intervention for day-to-day threat response.

**For a deep-dive into the architecture, security principles, and threat model, please see the [DESIGN.md](DESIGN.md) document.**

---

## High-Level Architecture

The platform consists of three key interacting systems: The CI/CD Pipeline for automated deployment, the Edge Security Platform for layered defense, and the Automated Defense Loop for real-time threat response.

![Architecture Diagram](docs/architecture.md)

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

### Prerequisites

*   An AWS Account.
*   A GitHub repository with the secrets `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` configured for the deployment workflows. (For a production system, it is highly recommended to use OIDC).
*   Terraform `~> 1.2.0` and Go `~> 1.18` for local testing.

### Deployment

The deployment is fully automated. Simply create a pull request with a change to the `terraform/` directory and merge it to `main` after the CI checks pass. The CD workflow will handle the rest.

For details on running the scripts and understanding the operational aspects, see the original [runbook-style README](docs/original_readme.md). (Note: I will move the old README there).

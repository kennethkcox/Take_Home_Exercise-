# Design & Architecture: The Self-Defending Edge

## 1. Vision & Goals

This document outlines the architecture for a production-grade, highly automated, and self-defending security platform on AWS. The goal is not merely to deploy an application, but to surround it with a robust, intelligent, and scalable security posture that requires minimal human intervention for day-to-day threat response.

This design aims to be a blueprint for a modern DevSecOps platform, suitable for presentation at a high-end engineering or security conference.

## 2. Security Design Principles

The architecture is guided by the following core security principles:

*   **Defense in Depth:** Security is not a single layer, but a series of overlapping controls. An attacker who bypasses one control should be caught by another. Our design implements layers at the edge (CloudFront), the network (WAF), the infrastructure (IAM, VPC), and the application runtime (container scanning).
*   **Automate Everything:** Humans should design systems, not operate them. All security responses, from blocking an IP to patching a container vulnerability, should be automated. Manual intervention is a sign of a design flaw.
*   **Least Privilege by Default:** Every component (IAM role, security group, etc.) must start with zero permissions and be granted only the specific permissions required to function.
*   **Shift Left, and Shift Right:** Security is not just a pre-deployment (shift left) activity like static analysis. It is also a continuous post-deployment (shift right) activity, involving real-time monitoring and automated response.
*   **Immutable Infrastructure:** We treat our infrastructure as cattle, not pets. All changes are made via code and deployed through an automated pipeline. No manual changes are made to the running environment.

## 3. High-Level Architecture

The platform consists of three key interacting systems:
1.  **The CI/CD Pipeline:** A fully automated workflow for testing, securing, and deploying code.
2.  **The Edge Security Platform:** A multi-layered defense at the edge of the network, consisting of CloudFront, AWS WAF, and Lambda@Edge.
3.  **The Automated Defense Loop:** A real-time feedback system that detects and responds to threats automatically.

*(The architecture diagram will be embedded here once created.)*

## 4. Threat Model & Mitigations

This is a simplified threat model focusing on the components we are building.

| Threat                                      | Mitigation                                                                                                                                                             |
| ------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Malicious Code in PR**                    | **CI Pipeline:** `tfsec` scan for IaC issues. Terratest validation. Manual approval gate on PR.                                                                        |
| **Vulnerable Container Image Deployed**     | **CI Pipeline:** Container image scanning with Trivy will be added to block deployment of images with known critical CVEs.                                              |
| **Common Web Attacks (XSS, SQLi)**          | **WAF:** AWS Managed Rule groups (`CommonRuleSet`, `SQLiRuleSet`) provide baseline protection. Custom rules provide application-specific protection.                        |
| **Lack of Security Headers**                | **Lambda@Edge:** A function will be deployed to automatically inject a strict Content-Security-Policy and other security headers into all responses.                    |
| **Targeted DoS or Brute-Force Attack**      | **Self-Defending WAF:** The automated response loop will detect high-velocity requests from single IPs and add them to a blocklist, mitigating the attack automatically. |
| **Compromised CI/CD Credentials**           | **OIDC Integration:** (Future phase) We will replace long-lived AWS access keys with short-lived, dynamically generated credentials via an OIDC trust relationship with GitHub Actions. |

## 5. Decision Log

*   **Why Terraform?** Chosen for its widespread adoption, declarative syntax, and strong support for managing AWS resources. It allows us to codify our entire infrastructure.
*   **Why GitHub Actions?** Chosen for its tight integration with the source code repository and its rich ecosystem of community-provided actions, which simplifies building complex CI/CD workflows.
*   **Why Lambda@Edge vs. CloudFront Functions?** Lambda@Edge was chosen for its flexibility and power, allowing complex logic and Node.js/Python runtimes. While CloudFront Functions are faster, they are more limited in scope and are intended for very simple, high-volume transformations.
*   **Why a "Self-Defending" Loop?** Manually blocking IPs is not scalable. An automated loop is the only way to handle the volume and velocity of modern automated attacks. It also reduces human error and response time from hours to seconds.

---
This document will be updated as the architecture evolves.

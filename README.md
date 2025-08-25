# Adobe Security – Take-Home Exercise Solution

This repository contains a solution for the Adobe Product Security Engineer take-home exercise. It demonstrates how to secure a web application (OWASP Juice Shop) using AWS WAF, managed with Infrastructure as Code (Terraform), and supported by a robust CI/CD and operational toolset.

## 1. Prerequisites

Before you begin, ensure you have the following installed and configured:

*   **AWS Account:** An active AWS account with sufficient permissions to create the resources defined in the Terraform code (VPC, ECS, ALB, WAF, S3, etc.).
*   **AWS CLI:** Configured with credentials (`aws configure`).
*   **Terraform:** Version `~> 1.2.0`
*   **Python 3:** With `pip` for installing script dependencies.
*   **Docker:** To potentially build and push images, although the default configuration uses a public image.

## 2. Setup

1.  **Clone the Repository:**
    ```bash
    git clone <repository-url>
    cd <repository-directory>
    ```

2.  **Review Terraform Variables:**
    The main variables are in `terraform/variables.tf`. You can modify the `default` values or create a `terraform.tfvars` file to override them, especially the `aws_region`.

    ```terraform
    variable "aws_region" {
      default = "us-east-1"
    }

    variable "project_name" {
      default = "adobe-sec-challenge"
    }
    ```

## 3. Deployment

The entire infrastructure is managed by Terraform. The deployment process is straightforward.

1.  **Initialize Terraform:**
    Navigate to the `terraform` directory and run `init`.
    ```bash
    cd terraform
    terraform init
    ```

2.  **Apply the Configuration:**
    Run `apply` to create all the AWS resources. This will take approximately 15-20 minutes.
    ```bash
    terraform apply -auto-approve
    ```

3.  **Get the Application URL:**
    Once the apply is complete, Terraform will output the DNS name of the Application Load Balancer.
    ```bash
    terraform output alb_dns_name
    ```
    You can now access the Juice Shop application at `http://<alb_dns_name>`.

## 4. Usage: Rapid Mitigation (`push_block.py`)

The `push_block.py` script allows for the rapid deployment of blocking rules to the WAF.

*   **Prerequisites:** Install Python dependencies.
    ```bash
    pip install boto3
    ```

*   **Usage Examples:**
    The script requires the WebACL name (which is `${var.project_name}-waf`) and the scope (`REGIONAL`).

    *   **Block an IP Address:**
        ```bash
        python ../push_block.py \
          --web-acl-name "adobe-sec-challenge-waf" \
          --scope REGIONAL \
          --ip "1.2.3.4/32"
        ```

    *   **Block a URI Path (Regex):**
        ```bash
        python ../push_block.py \
          --web-acl-name "adobe-sec-challenge-waf" \
          --scope REGIONAL \
          --uri ".*malicious-path.*"
        ```

## 5. Verification: Smoke Test (`smoke_test.py`)

The `smoke_test.py` script verifies that the WAF is correctly blocking known malicious requests while allowing benign traffic.

*   **Prerequisites:** Install Python dependencies.
    ```bash
    pip install requests
    ```

*   **Run the Test:**
    Replace `<alb_dns_name>` with the output from the `terraform output` command.
    ```bash
    python ../smoke_test.py http://<alb_dns_name>
    ```

*   **Expected Output:**
    ```
    --- Running Smoke Tests ---
    [*] Testing benign request to: http://<alb_dns_name>/
      [+] SUCCESS: Received 200 OK
    --------------------
    [*] Testing malicious SQLi request to: http://<alb_dns_name>/rest/products/search?q=%27%20OR%201=1--
      [+] SUCCESS: Received 403 Forbidden (WAF blocked the request)
    --- Smoke Tests Complete ---
    ```

## 6. KPI Query & Monitoring

WAF logs are sent to an S3 bucket via Kinesis Firehose and can be queried using AWS Athena.

*   **How to Query:**
    1.  Navigate to the **Athena** service in the AWS Console.
    2.  Select the `${var.project_name}_waf_logs` database.
    3.  Before running the query for the first time, load the partitions:
        ```sql
        MSCK REPAIR TABLE waf_logs;
        ```
    4.  Execute the query located in `kpi_query.sql`.

*   **KPI Monitoring Explanation:**
    Monitoring the KPIs provided by the Athena query is crucial for maintaining a strong security posture.
    *   **`percent_blocked`:** A sudden spike in this metric could indicate a widespread, automated attack, while a sudden drop might suggest a misconfiguration or a new bypass technique being used by attackers.
    *   **`top_5_attack_vectors`:** This helps the security team focus their tuning efforts. If a specific rule (e.g., a SQLi rule) is constantly being triggered, it validates its importance. Conversely, if a legitimate rule is causing a high number of false positives (blocking valid traffic), it will appear in this list, signaling that it needs to be refined or placed in count-only mode. Tracking these vectors over time helps measure the effectiveness of rule changes and can contribute to a faster Mean Time To Respond (MTTR) by quickly identifying and prioritizing the most prevalent threats.

## 7. Evidence

This section would contain the results from running the verification scripts and queries.

### Smoke Test Results

```
--- Running Smoke Tests ---
[*] Testing benign request to: http://<alb_dns_name>/
  [+] SUCCESS: Received 200 OK
--------------------
[*] Testing malicious SQLi request to: http://<alb_dns_name>/rest/products/search?q=%27%20OR%201=1--
  [+] SUCCESS: Received 403 Forbidden (WAF blocked the request)
--- Smoke Tests Complete ---
```

### KPI Query Results

*(Results would be populated here after generating traffic and running the Athena query)*

```json
{
  "total_requests": 100,
  "blocked_requests": 15,
  "percent_blocked": 15.0,
  "top_5_attack_vectors": {
    "awswaf:managed:aws:sql-database:SQLi_QueryArguments": 10,
    "JuiceShopSQLiBlock": 5
  }
}
```

## 8. CI/CD Guardrails

The `.github/workflows/edge-ci.yml` file implements a CI/CD pipeline with the following features:
*   Triggers on pull requests against the `main` branch.
*   Performs static analysis of Terraform code using `tfsec`.
*   Generates a `terraform plan` and posts it as a comment in the PR for review.
*   Includes a conceptual manual approval gate before any deployment.

---
*This solution was developed with AI assistance for generating boilerplate code and commands.*

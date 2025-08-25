# Foolproof Guide: From Zero to a Deployed Self-Defending Platform

This guide provides a detailed, step-by-step walkthrough for setting up, configuring, and deploying this project for the first time. No prior knowledge of the specific tools is assumed, but you should be comfortable with basic `git` commands and using the AWS and GitHub web consoles.

## Part 1: Prerequisites & Local Setup

Before you begin, you need to set up your local machine and accounts.

### 1.1: AWS Account
You need an active AWS account with administrative privileges to create the necessary resources.

### 1.2: GitHub Account
You need a GitHub account to fork and manage the repository.

### 1.3: Fork the Repository
1.  Navigate to the main repository page on GitHub.
2.  Click the **"Fork"** button in the top-right corner. This will create a personal copy of the repository under your own GitHub account.

### 1.4: Clone Your Fork Locally
1.  On your forked repository's page, click the green **"< > Code"** button.
2.  Copy the HTTPS or SSH URL.
3.  In your terminal, run:
    ```bash
    git clone <your-forked-repo-url>
    cd <repository-name>
    ```

### 1.5: Install Local Tools

#### For macOS & Linux
*   **Git:** Comes pre-installed on most systems. If not, use your package manager (e.g., `sudo apt-get install git`).
*   **Terraform:** The recommended way to install it is via `tfenv`, which manages multiple Terraform versions.
    *   **macOS:** `brew install tfenv`
    *   **Linux:** Follow the instructions at [https://github.com/tfutils/tfenv](https://github.com/tfutils/tfenv)
    *   Once `tfenv` is installed, run `tfenv install` in the repository root to automatically install the correct version.
*   **Go:** Required to run the IaC tests.
    *   **macOS:** `brew install go`
    *   **Linux:** `sudo apt-get install golang-go`
*   **Infracost:** Used to estimate cloud costs.
    *   **macOS:** `brew install infracost`
    *   **Linux:** Follow the instructions at [https://www.infracost.io/docs/install/](https://www.infracost.io/docs/install/)

#### For Windows
The recommended way to install these tools on Windows is by using the [Chocolatey](https://chocolatey.org/install) package manager. Open a PowerShell terminal as an Administrator to run these commands.

*   **Git:**
    *   `choco install git`
    *   *Alternative:* Download from [https://git-scm.com/download/win](https://git-scm.com/download/win).
*   **Terraform:**
    *   `choco install terraform`
    *   *Alternative:* Download from [https://www.terraform.io/downloads.html](https://www.terraform.io/downloads.html).
*   **Go:**
    *   `choco install golang`
    *   *Alternative:* Download from [https://golang.org/dl/](https://golang.org/dl/).
*   **Infracost:**
    *   `choco install infracost`
    *   *Alternative:* Download from [https://www.infracost.io/docs/install/](https://www.infracost.io/docs/install/).

## Part 2: Configure AWS & GitHub for Deployment

This is the most critical step. Instead of creating long-lived, insecure access keys, we will create a secure IAM Role in AWS that the GitHub Actions workflow can temporarily assume. This is a modern, secure best practice.

### 2.1: Create the IAM Deployment Role in AWS (One-Time Setup)

The repository includes a Terraform template to automate the creation of this role. You will need to run this once manually.

**Important Note:** Before starting, you must have your local environment authenticated to your AWS account (e.g., by running `aws configure` or setting environment variables).

**Step 1: Create a Configuration File**
1.  Navigate to the `terraform` directory in your local clone of the repository.
2.  Create a new file named `setup.tfvars`.
3.  Add the following content to the file, replacing the placeholder values with your GitHub username and the name of your forked repository:
    ```hcl
    # content for setup.tfvars
    github_owner = "your-github-username"
    github_repo  = "your-forked-repo-name"
    ```

**Step 2: Apply the Terraform Configuration to Create the Role**
1.  Open your terminal in the `terraform/` directory.
2.  Run `terraform init` to initialize the Terraform providers.
3.  Run the following command to create *only* the IAM role resources. This is a long command, but it uses the `-target` flag as a safety measure to ensure you don't accidentally try to deploy the whole application.

    ```bash
    terraform apply -var-file="setup.tfvars" \
      -target=data.aws_caller_identity.current \
      -target=data.aws_iam_policy_document.github_actions_trust_policy \
      -target=resource.aws_iam_role.github_actions_deployer_role \
      -target=data.aws_iam_policy_document.terraform_deployer_permissions \
      -target=resource.aws_iam_policy.terraform_deployer_policy \
      -target=resource.aws_iam_role_policy_attachment.deployer_attach
    ```
4.  Terraform will show you a plan and ask for confirmation. Type `yes` and press Enter.
5.  After the command completes, it will output a value for `iam_role_arn_for_github`. **Copy this full ARN value.** You will need it in the next step.

### 2.2: Configure Your GitHub Repository

Now, you need to provide the ARN of the role and other configuration to your GitHub repository so the workflow can use them.

**Step 1: Add Repository Variables**
1.  Navigate to your forked repository on GitHub.
2.  Go to **"Settings"** > **"Secrets and variables"** > **"Actions"**.
3.  Select the **"Variables"** tab.
4.  Click **"New repository variable"** for each of the following:
    *   `AWS_REGION`: The AWS region where you want to deploy the resources (e.g., `us-east-1`).
    *   `IAM_ROLE_TO_ASSUME`: Paste the full ARN you copied from the Terraform output in the previous step.

**Step 2: Add the Infracost Secret**
1.  While still in the "Actions" secrets and variables menu, select the **"Secrets"** tab.
2.  Click **"New repository secret"** for the following secret:
    *   `INFRACOST_API_KEY`: Get a free API key from [Infracost](https://www.infracost.io/docs/cloud_pricing/api_keys/) and paste it here. This is used by the CI pipeline to estimate costs.

Your repository is now fully configured to run the automated workflows using a secure OIDC connection.

## Part 3: Your First Deployment (The GitOps Workflow)

This project uses a GitOps workflow. This means all changes to the infrastructure are made via Pull Requests, which are automatically tested and then deployed upon merge.

### 3.1: Create a New Branch
It's best practice to make changes on a new branch.
```bash
git checkout -b my-first-change
```

### 3.2: Make a Safe Change
Let's make a small, safe change to see the process in action. Open the `terraform/main.tf` file and find the `aws_s3_bucket.waf_logs` resource. Add a new tag:
```terraform
resource "aws_s3_bucket" "waf_logs" {
  bucket = "${var.project_name}-waf-logs-${random_id.bucket_suffix.hex}"
  tags = {
    ManagedBy = "Terraform" # Add this line
  }
}
```

### 3.3: Commit and Push
```bash
git add .
git commit -m "feat: Add a test tag to the S3 bucket"
git push origin my-first-change
```

### 3.4: Open a Pull Request
1.  Go to your repository on GitHub. You will see a banner prompting you to create a Pull Request from your new branch. Click it.
2.  Give your PR a title and description, and click **"Create Pull Request"**.

### 3.5: Observe the CI Pipeline
1.  Once the PR is created, the "Edge Security CI" workflow will automatically start.
2.  Click on the "Checks" tab of your PR to see the progress.
3.  After a few minutes, you will see comments posted on your PR by the GitHub Actions bots:
    *   **Terratest:** Will confirm that your code is valid.
    *   **`tfsec`:** Will report any security issues.
    *   **`infracost`:** Will show you the cost impact of your change (which in this case will be $0).
    *   **Terraform Plan:** Will show you the exact changes Terraform will make.

### 3.6: Merge and Deploy
1.  Once all the checks are green, you can click **"Merge Pull Request"**.
2.  Merging to `main` will automatically trigger the "Edge Security CD" workflow.
3.  Click on the **"Actions"** tab of your repository to watch the deployment in real-time.
4.  The workflow will run `terraform apply`. This will take 15-20 minutes on the first run.
5.  After the deployment, the workflow will run the smoke test to verify the application is healthy.

### 3.7: Find Your Application
Once the CD workflow is complete, the Juice Shop application is live. To find the URL:
1.  Go to the **"Actions"** tab in your repository and click on the completed "Edge Security CD" workflow run.
2.  The application URL is printed in the **summary** of the run, at the top of the page.
3.  You can also find it in the logs of the "Get ALB DNS Name" step.

Congratulations! You have successfully deployed a state-of-the-art, self-defending cloud security platform.

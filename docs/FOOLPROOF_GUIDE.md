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
*   **Terraform:** This is used to manage the infrastructure. The recommended way to install it is via `tfenv`, which allows you to manage multiple Terraform versions.
    *   **macOS:** `brew install tfenv`
    *   **Linux:** Follow the instructions at [https://github.com/tfutils/tfenv](https://github.com/tfutils/tfenv)
    *   Once `tfenv` is installed, run `tfenv install` in the repository root. It will automatically pick up the version from the `.terraform-version` file.
*   **Go:** This is required to run the IaC tests.
    *   **macOS:** `brew install go`
    *   **Linux:** `sudo apt-get install golang-go`
*   **Infracost:** This is used to estimate cloud costs.
    *   **macOS:** `brew install infracost`
    *   **Linux:** Follow the instructions at [https://www.infracost.io/docs/install/](https://www.infracost.io/docs/install/)

## Part 2: Configuring Secrets

This is the most critical step. Our automated workflows need credentials to interact with AWS and other services. These are stored securely as GitHub Actions secrets.

### 2.1: Create AWS Credentials
1.  Log in to your AWS Console.
2.  Navigate to the **IAM** service.
3.  Go to **Users** and click **"Add users"**.
4.  Give the user a name (e.g., `github-actions-deployer`).
5.  Select **"Access key - Programmatic access"** as the credential type.
6.  Attach the `AdministratorAccess` policy directly. **Note:** This is for simplicity in this exercise. In a real production environment, you should create a custom policy with the exact, least-privilege permissions required by the Terraform code.
7.  Click through the tags and user creation steps.
8.  **IMPORTANT:** On the final screen, you will see the **Access key ID** and the **Secret access key**. Copy these immediately and save them somewhere secure. You will not be able to see the secret key again.

### 2.2: Get an Infracost API Key
1.  Navigate to [https://www.infracost.io/](https://www.infracost.io/).
2.  Follow the steps to get a free API key. It's a quick process. Copy the API key you receive.

### 2.3: Add Secrets to Your GitHub Repository
1.  Navigate to your forked repository on GitHub.
2.  Click on **"Settings"** > **"Secrets and variables"** > **"Actions"**.
3.  Click **"New repository secret"** for each of the following secrets:
    *   **`AWS_ACCESS_KEY_ID`**: Paste the Access key ID you created in step 2.1.
    *   **`AWS_SECRET_ACCESS_KEY`**: Paste the Secret access key you created in step 2.1.
    *   **`INFRACOST_API_KEY`**: Paste the API key you got from Infracost in step 2.2.

Your repository is now fully configured to run the automated workflows.

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
1.  Go to the completed "Edge Security CD" workflow run.
2.  Look at the output of the "Get ALB DNS Name" step. It will contain the public URL for your application.

Congratulations! You have successfully deployed a state-of-the-art, self-defending cloud security platform.

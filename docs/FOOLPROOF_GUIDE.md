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

## Part 2: Configuring Secrets

This is the most critical step. Our automated workflows need credentials to interact with AWS and other services. These are stored securely as GitHub Actions secrets.

### 2.1: Create AWS Credentials for Programmatic Access

These steps will guide you through creating a dedicated IAM user with the necessary permissions and credentials for the automated workflows.

#### Step 1: Create the IAM User
1.  Log in to your **AWS Management Console**.
2.  In the main search bar at the top, type **"IAM"** and select it from the results to navigate to the IAM dashboard.
3.  In the left-hand navigation pane, click on **"Users"**.
4.  Click the **"Create user"** button.
5.  **User details:**
    *   Enter a **User name** (e.g., `github-actions-deployer`).
    *   Do **not** check the box for "Provide user access to the AWS Management Console". This user is for programmatic access only.
    *   Click **"Next"**.
6.  **Set permissions:**
    *   Select **"Attach policies directly"**.
    *   In the search box under "Permissions policies", type `AdministratorAccess`.
    *   Check the box next to the `AdministratorAccess` policy.
    *   **Note:** This is for simplicity in this exercise. In a real production environment, you should create a custom policy with the exact, least-privilege permissions required by the Terraform code.
    *   Click **"Next"**.
7.  **Review and create:**
    *   Review the details to ensure the user name is correct and the `AdministratorAccess` policy is attached.
    *   Click **"Create user"**.

#### Step 2: Create and Retrieve Access Keys
After the user is created, you will be redirected to the user list. You now need to generate the credentials.

1.  From the user list, click on the name of the user you just created (e.g., `github-actions-deployer`).
2.  On the user's summary page, click the **"Security credentials"** tab.
3.  Scroll down to the **"Access keys"** section and click **"Create access key"**.
4.  **Select use case:**
    *   Choose **"Command Line Interface (CLI)"**. This is the most appropriate option for our use case, as it indicates the keys will be used for programmatic access from outside AWS.
    *   Read and check the acknowledgment box.
    *   Click **"Next"**.
5.  **Set description tag (Optional):**
    *   You can add a tag to help you identify this key later (e.g., `GitHub Actions Key`).
    *   Click **"Create access key"**.
6.  **Retrieve access keys:**
    *   **IMPORTANT:** This is your only opportunity to view and save the secret access key.
    *   You will see the **Access key ID** and the **Secret access key**.
    *   Copy both values and save them somewhere secure (like a password manager). You will need them for the next step.
    *   Click **"Done"**.

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

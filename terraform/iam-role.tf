# This file is intended to be run ONCE MANUALLY to set up the IAM Role for GitHub Actions.
# Do NOT include this file in the main Terraform state for the application.
# It provides a semi-automated, secure way to create the necessary deployment role.
#
# Instructions:
# 1. Ensure you have an OIDC provider for GitHub in your AWS account. If not, create one.
#    (See AWS documentation for "Configuring OpenID Connect in Amazon Web Services")
# 2. Create a file named `setup.tfvars` with your GitHub details:
#    github_owner = "your-github-username"
#    github_repo  = "your-repo-name"
# 3. Run the following commands in the `terraform/` directory:
#    terraform init
#    terraform apply -var-file="setup.tfvars" -target=aws_iam_role.github_actions_deployer_role -target=aws_iam_policy.terraform_deployer_policy -target=aws_iam_role_policy_attachment.deployer_attach
# 4. The output will be the ARN of the role to use in your GitHub repository variables.

variable "github_owner" {
  description = "The owner of the GitHub repository (e.g., your GitHub username)."
  type        = string
}

variable "github_repo" {
  description = "The name of the GitHub repository."
  type        = string
}

variable "iam_role_name" {
  description = "The name of the IAM role to create."
  type        = string
  default     = "GitHubAction-Terraform-Deployer"
}

data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "github_actions_trust_policy" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/token.actions.githubusercontent.com"]
    }
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github_owner}/${var.github_repo}:*"]
    }
  }
}

resource "aws_iam_role" "github_actions_deployer_role" {
  name               = var.iam_role_name
  assume_role_policy = data.aws_iam_policy_document.github_actions_trust_policy.json
  description        = "IAM Role for GitHub Actions to deploy the Self-Defending Edge project."
}

# NOTE: This policy is more permissive than ideal for a hardened production environment.
# It is, however, a significant improvement over AdministratorAccess by scoping permissions
# to the services required by this project's Terraform configuration.
# For a real production deployment, you should further restrict these permissions using tools like iamlive.
data "aws_iam_policy_document" "terraform_deployer_permissions" {
  statement {
    effect    = "Allow"
    actions   = [
      "s3:*",
      "cloudfront:*",
      "lambda:*",
      "iam:CreateRole", "iam:DeleteRole", "iam:GetRole", "iam:PassRole", "iam:AttachRolePolicy", "iam:DetachRolePolicy", "iam:PutRolePolicy", "iam:DeleteRolePolicy", "iam:ListAttachedRolePolicies",
      "logs:*",
      "cloudwatch:*",
      "firehose:*",
      "ec2:Describe*", "ec2:CreateSecurityGroup", "ec2:DeleteSecurityGroup", "ec2:AuthorizeSecurityGroupIngress", "ec2:RevokeSecurityGroupIngress",
      "elasticloadbalancing:*",
      "ecs:*",
      "sns:*",
      "wafv2:*"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "terraform_deployer_policy" {
  name        = "${var.iam_role_name}-Policy"
  policy      = data.aws_iam_policy_document.terraform_deployer_permissions.json
  description = "Permissions for the Self-Defending Edge Terraform deployment."
}

resource "aws_iam_role_policy_attachment" "deployer_attach" {
  role       = aws_iam_role.github_actions_deployer_role.name
  policy_arn = aws_iam_policy.terraform_deployer_policy.arn
}

output "iam_role_arn_for_github" {
  value       = aws_iam_role.github_actions_deployer_role.arn
  description = "The ARN of the created IAM role. Use this value for the IAM_ROLE_TO_ASSUME repository variable in GitHub."
}

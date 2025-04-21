data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "eks_read_policy_document" {
  statement {
    effect    = "Allow"
    actions   = ["eks:*"]
    resources = ["*"]
  }

  statement {
    effect = "Allow"

    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:BatchGetImage",
      "ecr:DescribeImages",
      "ecr:DescribeRepositories",
      "ecr:GetDownloadUrlForLayer"
    ]

    resources = ["*"]
  }
}

data "aws_iam_policy_document" "assume_role_policy_document" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
  }
}

resource "aws_iam_role" "kube_admin_role" {
  name               = "${var.cluster_name}-kube-admin"
  assume_role_policy = data.aws_iam_policy_document.assume_role_policy_document.json
}

resource "aws_iam_role_policy" "kube_allowed_to_read" {
  name   = "${var.cluster_name}-kube-allowed-to-read"
  role   = aws_iam_role.kube_admin_role.id
  policy = data.aws_iam_policy_document.eks_read_policy_document.json
}
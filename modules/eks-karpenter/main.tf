module "karpenter" {
  source                 = "terraform-aws-modules/eks/aws//modules/karpenter"
  version                = "20.35.0"
  cluster_name           = var.cluster_name
  irsa_oidc_provider_arn = var.cluster_oidc_provider_arn
  enable_irsa            = true
  enable_v1_permissions  = true

  node_iam_role_additional_policies = {
    AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
    CloudWatchReadOnlyAccess     = "arn:aws:iam::aws:policy/CloudWatchReadOnlyAccess"
  }
}
resource "helm_release" "karpenter" {
  namespace        = "karpenter"
  create_namespace = true
  name             = "karpenter"
  repository       = "oci://public.ecr.aws/karpenter"
  chart            = "karpenter"
  timeout          = var.addon_timeout
  version          = var.addon_version
  wait             = false
  wait_for_jobs    = false

  set {
    name  = "settings.clusterName"
    value = var.cluster_name
  }

  set {
    name  = "replicas"
    value = "1"
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.karpenter.iam_role_arn
  }

  set {
    name  = "settings.aws.clusterEndpoint"
    value = var.cluster_endpoint
  }

  set {
    name  = "settings.aws.interruptionQueueName"
    value = module.karpenter.queue_name
  }

  depends_on = [module.karpenter]
}
resource "helm_release" "karpenter" {
  namespace        = "karpenter"
  create_namespace = true
  name             = "karpenter"
  repository       = "oci://public.ecr.aws/karpenter"
  chart            = "karpenter-crd"
  upgrade_install  = true
  timeout          = var.addon_timeout
  version          = var.addon_version
  wait             = false
  wait_for_jobs    = false

  set {
    name  = "webhook.enabled"
    value = true
  }

  set {
    name  = "webhook.serviceName"
    value = "karpenter"
  }

  set {
    name  = "swebhook.port"
    value = "8443"
  }

  depends_on = [module.karpenter]
}

resource "aws_iam_policy" "karpenter_spot_permission" {
  name        = "KarpenterSpotPermission"
  description = "allow Karpenter to create spot instances"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow"
        Action   = "iam:CreateServiceLinkedRole"
        Resource = "*"
        Condition = {
          StringLike = {
            "iam:AWSServiceName" : "spot.amazonaws.com"
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "attach_policy" {
  role       = module.karpenter.iam_role_name
  policy_arn = aws_iam_policy.karpenter_spot_permission.arn
}
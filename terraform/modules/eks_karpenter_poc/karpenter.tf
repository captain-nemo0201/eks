# RECOMMENDATION: For production, add an On-Demand fallback NodePool per arch.
# Spot capacity can be temporarily unavailable; fallback prevents pods from staying Pending.

module "karpenter" {
  source  = "terraform-aws-modules/eks/aws//modules/karpenter"
  version = "~> 20.0"

  cluster_name = module.eks.cluster_name

  enable_irsa         = false
  enable_pod_identity = true

  create_node_iam_role = true
  node_iam_role_name   = "${var.name}-karpenter-node"

  create_iam_role = true
  iam_role_name   = "${var.name}-karpenter-controller"

  create_queue = true

  tags = local.tags
}

resource "kubernetes_namespace" "karpenter" {
  provider = kubernetes.this
  metadata {
    name = "karpenter"
    labels = {
      "pod-security.kubernetes.io/enforce" = "privileged"
    }
  }
}

resource "helm_release" "karpenter" {
  provider  = helm.this
  name      = "karpenter"
  namespace = kubernetes_namespace.karpenter.metadata[0].name

  repository = "oci://public.ecr.aws/karpenter"
  chart      = "karpenter"
  version    = var.karpenter_chart_version

  set { name = "settings.clusterName"        value = module.eks.cluster_name }
  set { name = "settings.interruptionQueue" value = module.karpenter.queue_name }

  # Чтобы запускаться на bootstrap node group с CriticalAddonsOnly taint
  set { name = "tolerations[0].key"      value = "CriticalAddonsOnly" }
  set { name = "tolerations[0].operator" value = "Equal" }
  set { name = "tolerations[0].value"    value = "true" }
  set { name = "tolerations[0].effect"   value = "NoSchedule" }

  set { name = "serviceAccount.name"   value = "karpenter" }
  set { name = "serviceAccount.create" value = "true" }

  depends_on = [
    module.eks,
    module.karpenter,
    kubernetes_namespace.karpenter
  ]
}

resource "aws_eks_pod_identity_association" "karpenter" {
  cluster_name    = module.eks.cluster_name
  namespace       = "karpenter"
  service_account = "karpenter"
  role_arn        = module.karpenter.iam_role_arn

  depends_on = [helm_release.karpenter]
}

resource "kubernetes_manifest" "ec2_node_class" {
  provider = kubernetes.this
  manifest = {
    apiVersion = "karpenter.k8s.aws/v1beta1"
    kind       = "EC2NodeClass"
    metadata = { name = "default" }
    spec = {
      role = module.karpenter.node_iam_role_name

      subnetSelectorTerms = [
        { tags = { "karpenter.sh/discovery" = var.name } }
      ]

      securityGroupSelectorTerms = [
        { tags = { "aws:eks:cluster-name" = module.eks.cluster_name } }
      ]

      tags = merge(local.tags, {
        "karpenter.sh/discovery" = var.name
      })
    }
  }

  depends_on = [helm_release.karpenter]
}

resource "kubernetes_manifest" "nodepool_arm64_spot" {
  provider = kubernetes.this
  manifest = {
    apiVersion = "karpenter.sh/v1beta1"
    kind       = "NodePool"
    metadata = { name = "arm64-spot" }
    spec = {
      template = {
        metadata = {
          labels = {
            "workload-arch" = "arm64"
            "capacity-type" = "spot"
          }
        }
        spec = {
          nodeClassRef = { name = "default" }
          requirements = [
            { key = "kubernetes.io/arch",           operator = "In", values = ["arm64"] },
            { key = "karpenter.sh/capacity-type",   operator = "In", values = ["spot"]  },
            { key = "karpenter.k8s.aws/instance-family", operator = "In", values = ["c7g","m7g","r7g","t4g"] }
          ]
        }
      }

      disruption = {
        consolidationPolicy = "WhenEmptyOrUnderutilized"
        expireAfter         = "720h"
      }

      limits = {
        cpu    = "2000"
        memory = "4000Gi"
      }
    }
  }

  depends_on = [kubernetes_manifest.ec2_node_class]
}

resource "kubernetes_manifest" "nodepool_amd64_spot" {
  provider = kubernetes.this
  manifest = {
    apiVersion = "karpenter.sh/v1beta1"
    kind       = "NodePool"
    metadata = { name = "amd64-spot" }
    spec = {
      template = {
        metadata = {
          labels = {
            "workload-arch" = "amd64"
            "capacity-type" = "spot"
          }
        }
        spec = {
          nodeClassRef = { name = "default" }
          requirements = [
            { key = "kubernetes.io/arch",           operator = "In", values = ["amd64"] },
            { key = "karpenter.sh/capacity-type",   operator = "In", values = ["spot"]  },
            { key = "karpenter.k8s.aws/instance-family", operator = "In", values = ["c7i","m7i","r7i","c6i","m6i","r6i"] }
          ]
        }
      }

      disruption = {
        consolidationPolicy = "WhenEmptyOrUnderutilized"
        expireAfter         = "720h"
      }

      limits = {
        cpu    = "2000"
        memory = "4000Gi"
      }
    }
  }

  depends_on = [kubernetes_manifest.ec2_node_class]
}

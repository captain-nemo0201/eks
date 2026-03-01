module "eks_karpenter" {
  source = "./modules/eks_karpenter_poc"

  name                    = var.name
  region                  = var.region
  cluster_version         = var.cluster_version
  vpc_cidr                = var.vpc_cidr
  az_count                = var.az_count
  tags                    = var.tags
  karpenter_chart_version = var.karpenter_chart_version
}

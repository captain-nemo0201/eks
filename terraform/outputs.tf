output "cluster_name" {
  value = module.eks_karpenter.cluster_name
}

output "cluster_endpoint" {
  value = module.eks_karpenter.cluster_endpoint
}

output "region" {
  value = var.region
}

output "configure_kubectl" {
  description = "Команда для обновления kubeconfig"
  value       = "aws eks update-kubeconfig --region ${var.region} --name ${module.eks_karpenter.cluster_name}"
}

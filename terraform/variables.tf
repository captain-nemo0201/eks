variable "name" {
  description = "Environment/cluster name (used for resource naming)"
  type        = string
  default     = "startup-eks"
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "eu-central-1"
}

variable "cluster_version" {
  description = "Kubernetes version for EKS"
  type        = string
  default     = "1.35"
}

variable "vpc_cidr" {
  description = "CIDR for the dedicated VPC"
  type        = string
  default     = "10.20.0.0/16"
}

variable "az_count" {
  description = "Number of AZs to use"
  type        = number
  default     = 3
}

variable "tags" {
  description = "Additional tags"
  type        = map(string)
  default     = {}
}

# Karpenter chart version: можно фиксировать под ваш релизный процесс
variable "karpenter_chart_version" {
  description = "Karpenter Helm chart version (OCI: public.ecr.aws/karpenter/karpenter)"
  type        = string
  default     = "1.9.0"
}

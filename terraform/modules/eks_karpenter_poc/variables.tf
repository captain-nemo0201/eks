variable "name" {
  description = "Environment/cluster name"
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string
}

variable "cluster_version" {
  description = "Kubernetes version for EKS"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR for the dedicated VPC"
  type        = string
}

variable "az_count" {
  description = "Number of AZs"
  type        = number
}

variable "tags" {
  description = "Tags"
  type        = map(string)
}

variable "karpenter_chart_version" {
  description = "Karpenter Helm chart version"
  type        = string
}

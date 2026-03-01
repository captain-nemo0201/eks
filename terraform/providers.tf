provider "aws" {
  region = var.region
}

# NOTE:
# Kubernetes/Helm providers are configured INSIDE the module (with provider aliases),
# because they require the EKS endpoint and auth token that are only known after
# the cluster is created.

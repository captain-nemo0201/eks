data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  azs = slice(data.aws_availability_zones.available.names, 0, var.az_count)

  tags = merge({
    "Project"     = var.name
    "ManagedBy"   = "Terraform"
    "Environment" = "poc"
  }, var.tags)
}

provider "aws" {
  allowed_account_ids = [var.aws_account]
  region              = var.aws_region
}
terraform {
  backend "remote" {
    organization = "pleeo"

    workspaces {
      name = "gitops-demo"
    }
  }
}
data "aws_region" "current" {
}
data "aws_subnet_ids" "public" {
  vpc_id = var.vpc_id
  tags = {
    Tier = "Public"
  }
}
data "aws_subnet_ids" "private" {
  vpc_id = var.vpc_id

  tags = {
    Tier = "Private"
  }
}
data "aws_subnet" "public" {
  for_each = data.aws_subnet_ids.public.ids
  id       = each.value
}
data "aws_subnet" "private" {
  for_each = data.aws_subnet_ids.private.ids
  id       = each.value
}
module "kubernetes" {
  source               = "scholzj/kubernetes/aws"
  version              = "1.14.0"
  aws_region           = data.aws_region.current.name
  cluster_name         = "aws-k8s"
  master_instance_type = "t3a.medium"
  worker_instance_type = "t3a.large"
  ssh_public_key       = "id_rsa.pub"
  ssh_access_cidr      = ["0.0.0.0/0"]
  api_access_cidr      = ["0.0.0.0/0"]
  min_worker_count     = 0
  max_worker_count     = 2
  hosted_zone          = var.hosted_zone
  hosted_zone_private  = false
  master_subnet_id     = tolist(data.aws_subnet_ids.public.ids)[0]
  worker_subnet_ids = [for id in data.aws_subnet.private : id.id]

  # Tags
  tags = {
    Application = "AWS-Kubernetes"
  }

  # Tags in a different format for Auto Scaling Group
  tags2 = [
    {
      key                 = "Application"
      value               = "AWS-Kubernetes"
      propagate_at_launch = true
    }
  ]

  addons = [
    "https://raw.githubusercontent.com/scholzj/terraform-aws-kubernetes/master/addons/metrics-server.yaml",
    "https://raw.githubusercontent.com/scholzj/terraform-aws-kubernetes/master/addons/autoscaler.yaml"
  ]
}

//variables
variable "aws_account" {
  type = string
}

variable "aws_region" {
  type    = string
  default = "us-west-1"
}

variable "hosted_zone" {
  type = string
}
variable "vpc_id" {
  type = string
}

//output
output "master_ip" {
  value = module.kubernetes.public_ip
}
resource "random_string" "suffix" {
  length  = 8
  special = false
}

locals {
  vpc_id              = module.vpc.vpc_id
  vpc_cidr            = module.vpc.vpc_cidr_block
  public_subnets_ids  = module.vpc.public_subnets
  private_subnets_ids = module.vpc.private_subnets
  subnets_ids         = concat(local.public_subnets_ids, local.private_subnets_ids)
  cluster_name = "${var.used_name}-${random_string.suffix.result}"
  name = "${var.used_name}"
}
################################################################################
# VPC Module
################################################################################
module "vpc" {
  source = "./modules/vpc"
  
  used_name           = var.used_name
  cluster_name        = local.cluster_name
  
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "19.15.3"

  cluster_name    = local.cluster_name
  cluster_version = "1.27"

  vpc_id                         = module.vpc.vpc_id
  subnet_ids                     = module.vpc.private_subnets
  cluster_endpoint_public_access = true

  eks_managed_node_group_defaults = {
    ami_type = "AL2_x86_64"

  }

  eks_managed_node_groups = {
    one = {
      name = "node-group-1"

      instance_types = ["t3.small"]

      min_size     = 1
      max_size     = 3
      desired_size = 2
    }

    two = {
      name = "node-group-2"

      instance_types = ["t3.small"]

      min_size     = 1
      max_size     = 2
      desired_size = 1
    }
  }
}


# https://aws.amazon.com/blogs/containers/amazon-ebs-csi-driver-is-now-generally-available-in-amazon-eks-add-ons/ 
data "aws_iam_policy" "ebs_csi_policy" {
  arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

module "irsa-ebs-csi" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-role-with-oidc"
  version = "4.7.0"

  create_role                   = true
  role_name                     = "AmazonEKSTFEBSCSIRole-${module.eks.cluster_name}"
  provider_url                  = module.eks.oidc_provider
  role_policy_arns              = [data.aws_iam_policy.ebs_csi_policy.arn]
  oidc_fully_qualified_subjects = ["system:serviceaccount:kube-system:ebs-csi-controller-sa"]
}

resource "aws_eks_addon" "ebs-csi" {
  cluster_name             = module.eks.cluster_name
  addon_name               = "aws-ebs-csi-driver"
  addon_version            = "v1.20.0-eksbuild.1"
  service_account_role_arn = module.irsa-ebs-csi.iam_role_arn
  tags = {
    "eks_addon" = "ebs-csi"
    "terraform" = "true"
  }
}



################################################################################
# AWS ALB Controller
################################################################################

module "aws_alb_controller" {
  source = "./modules/aws-alb-controller"
  
  region  = var.region
  env_name     = var.used_name
  cluster_name = local.cluster_name

  vpc_id            = module.vpc.vpc_id
  oidc_provider_arn = module.eks.oidc_provider_arn
}

################################################################################
# AWS EFS MODULE
################################################################################

module "EFS" {
  source = "./modules/efs"

  vpc_id            = module.vpc.vpc_id
  vpc_cidr          = module.vpc.vpc_cidr_block
  oidc_provider_arn = module.eks.oidc_provider_arn
  private_subnets   = module.vpc.private_subnets

}

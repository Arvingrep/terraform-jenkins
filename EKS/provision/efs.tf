
#参考：https://medium.com/aws-infrastructure/add-efs-csi-drivers-to-your-eks-kubernetes-cluster-using-terraform-with-helm-provider-bbc21b9ce40b
provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
      command     = "aws"
    }
  }
}


locals {
  vpc_id              = module.vpc.vpc_id
  vpc_cidr            = module.vpc.vpc_cidr_block
  public_subnets_ids  = module.vpc.public_subnets
  private_subnets_ids = module.vpc.private_subnets
  subnets_ids         = concat(local.public_subnets_ids, local.private_subnets_ids)
}



################
#  EKS MODULE  #
################

# module "eks" {
#   source  = "terraform-aws-modules/eks/aws"
#   version = "~> 19.0"

#   cluster_name    = "stw-cluster"
#   cluster_version = "1.24"

#   cluster_endpoint_public_access = true

#   cluster_addons = {
#     kube-proxy = {
#       most_recent = true
#     }
#     vpc-cni = {
#       most_recent              = true
#       before_compute           = true
#       service_account_role_arn = module.vpc_cni_irsa.iam_role_arn
#       configuration_values = jsonencode({
#         env = {
#           # Reference docs https://docs.aws.amazon.com/eks/latest/userguide/cni-increase-ip-addresses.html
#           ENABLE_PREFIX_DELEGATION = "true"
#           WARM_PREFIX_TARGET       = "1"
#         }
#       })
#     }
#   }

#   vpc_id                   = local.vpc_id
#   subnet_ids               = local.private_subnets_ids
#   control_plane_subnet_ids = local.private_subnets_ids

#   # EKS Managed Node Group(s)
#   eks_managed_node_group_defaults = {
#     ami_type                   = "AL2_x86_64"
#     instance_types             = ["t3.medium"]
#     iam_role_attach_cni_policy = true
#   }

#   eks_managed_node_groups = {
#     stw_node_wg = {
#       min_size     = 2
#       max_size     = 6
#       desired_size = 2
#     }
#   }

# }







########################
#  EKS DRIVER FOR EFS  #
########################

resource "helm_release" "aws_efs_csi_driver" {
  chart      = "aws-efs-csi-driver"
  name       = "aws-efs-csi-driver"
  namespace  = "kube-system"
  repository = "https://kubernetes-sigs.github.io/aws-efs-csi-driver/"

  set {
    name  = "image.repository"
    value = "602401143452.dkr.ecr.eu-west-3.amazonaws.com/eks/aws-efs-csi-driver"
  }

  set {
    name  = "controller.serviceAccount.create"
    value = true
  }

  set {
    name  = "controller.serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.attach_efs_csi_role.iam_role_arn
  }

  set {
    name  = "controller.serviceAccount.name"
    value = "efs-csi-controller-sa"
  }
}






################################
#  ROLES FOR SERVICE ACCOUNTS  #
################################

module "vpc_cni_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name_prefix      = "VPC-CNI-IRSA"
  attach_vpc_cni_policy = true
  vpc_cni_enable_ipv4   = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-node"]
    }
  }
}


module "attach_efs_csi_role" {
  source = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"

  role_name             = "efs-csi"
  attach_efs_csi_policy = true

  oidc_providers = {
    ex = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:efs-csi-controller-sa"]
    }
  }
}







#########
#  EFS  #
#########

resource "aws_security_group" "allow_nfs" {
  name        = "allow nfs for efs"
  description = "Allow NFS inbound traffic"
  vpc_id      = local.vpc_id

  ingress {
    description = "NFS from VPC"
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
    cidr_blocks = [local.vpc_cidr]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

}


resource "aws_efs_file_system" "efs_file_system" {
  creation_token = "efs-for-stw-node"

  lifecycle {
    # prevent_destroy = true
  }
}


# resource "aws_efs_mount_target" "stw_node_efs_mt_0" {
#   file_system_id  = aws_efs_file_system.stw_node_efs.id
#   subnet_id       = module.vpc.private_subnets[0]
#   security_groups = [aws_security_group.allow_nfs.id]
# }

# resource "aws_efs_mount_target" "stw_node_efs_mt_1" {
#   file_system_id  = aws_efs_file_system.stw_node_efs.id
#   subnet_id       = module.vpc.private_subnets[1]
#   security_groups = [aws_security_group.allow_nfs.id]
# }

# Resource: EFS Mount Target
resource "aws_efs_mount_target" "efs_mount_target" {
  #for_each = toset(module.vpc.private_subnets)
  count = 2
  file_system_id = aws_efs_file_system.efs_file_system.id
  subnet_id      = module.vpc.private_subnets[count.index]
  security_groups = [ aws_security_group.allow_nfs.id ]
}



# EFS File System ID
output "efs_file_system_id" {
  description = "EFS File System ID"
  value = aws_efs_file_system.efs_file_system.id 
}

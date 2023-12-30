################################################################################
# General Variables from root module
################################################################################

 


################################################################################
# Variables from other Modules
################################################################################

variable "vpc_id" {
  description = "VPC ID which EFS will be  deployed in"
  type = string
}


variable "private_subnets" {
  description = " private_subnets which EFS will be  deployed in"

}


variable "vpc_cidr" {
  description = "VPC ID which EFS will be  deployed in"
  type = string
}

variable "oidc_provider_arn" {
  description = "OIDC Provider ARN used for IRSA "
  type = string
}

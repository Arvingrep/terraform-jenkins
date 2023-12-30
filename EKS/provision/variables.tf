# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0


################################################################################
# EKS Cluster Variables
################################################################################


variable "region" {
  description = "AWS region"
  type        = string
  default     = "ap-southeast-1"
}

variable "used_name" {
  description = "env used name"
  type = string
  default = "terraform-jenkins"
}

variable "aws_secret_access_key" {
  description = "aws_secret_access_key  in the terraform"
}
variable "aws_access_key_id" {
  description = "aws_access_key_id  in the terraform"
}

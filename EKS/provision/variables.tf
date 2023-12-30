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


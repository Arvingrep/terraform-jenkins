terraform {
  cloud {
    organization = "2up"
    workspaces {
      name = "terraform-jenkins-EKS-manage"
    }
  }
}
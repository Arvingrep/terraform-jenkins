terraform {
    cloud {
        organization = "2up"
        workspaces {
            name = "terraform-jenkins-GKE-manage"
        }
    }
    required_providers {
        google = {
            source  = "hashicorp/google"
            version = "4.27.0"
        }
        kubernetes = {
            source  = "hashicorp/kubernetes"
            version = ">= 2.0.1"
        }
        helm = {
            source = "hashicorp/helm"
            version = "2.8.0"
        }
    }
    required_version = ">= 0.14"
}
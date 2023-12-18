# ## GKE resources
data "terraform_remote_state" "gke" {
  backend = "remote"
  config = {
    organization = "2up"
    workspaces = {
      name = "terraform-jenkins-GKE-provision"
    }
  }
}

# Retrieve GKE cluster information
provider "google" {
  project = data.terraform_remote_state.gke.outputs.project_id
  region  = data.terraform_remote_state.gke.outputs.region
}

# Configure kubernetes provider with Oauth2 access token.
# https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/client_config
# This fetches a new token, which will expire in 1 hour.
data "google_client_config" "default" {}

data "google_container_cluster" "my_cluster" {
  name     = data.terraform_remote_state.gke.outputs.kubernetes_cluster_name
  location = data.terraform_remote_state.gke.outputs.region
}

provider "kubernetes" {
  alias = "gke"
  host = data.terraform_remote_state.gke.outputs.kubernetes_cluster_host

  token                  = data.google_client_config.default.access_token
  cluster_ca_certificate = base64decode(data.google_container_cluster.my_cluster.master_auth[0].cluster_ca_certificate)
}

provider "helm" {
  alias = "gke"
  kubernetes {
    host                   = "${data.google_container_cluster.my_cluster.endpoint}"
    token                  = "${data.google_client_config.default.access_token}"
    client_certificate     = "${base64decode(data.google_container_cluster.my_cluster.master_auth.0.client_certificate)}"
    client_key             = "${base64decode(data.google_container_cluster.my_cluster.master_auth.0.client_key)}"
    cluster_ca_certificate = "${base64decode(data.google_container_cluster.my_cluster.master_auth.0.cluster_ca_certificate)}"
  }
}

resource "kubernetes_pod" "counting" {
  provider = kubernetes.gke

  metadata {
    name = "counting"
    labels = {
      "app" = "counting"
    }
  }

  spec {
    container {
      image = "hashicorp/counting-service:0.0.2"
      name  = "counting"

      port {
        container_port = 9001
        name           = "http"
      }
    }
  }
}

resource "kubernetes_service" "counting" {
  provider = kubernetes.gke
  metadata {
    name      = "counting"
    namespace = "default"
    labels = {
      "app" = "counting"
    }
  }
  spec {
    selector = {
      "app" = "counting"
    }
    port {
      name        = "http"
      port        = 9001
      target_port = 9001
      protocol    = "TCP"
    }
    type = "ClusterIP"
  }
}

# EKS resources 

data "terraform_remote_state" "eks" {
  backend = "remote"
  config = {
    organization = "2up"
    workspaces = {
      name = "terraform-jenkins-EKS-provision"
    }
  }
}

provider "aws" {
  region = data.terraform_remote_state.eks.outputs.region
}

data "aws_eks_cluster" "cluster" {
  name = data.terraform_remote_state.eks.outputs.cluster_id
}

provider "kubernetes" {
  alias                  = "eks"
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
  exec {
    api_version = "client.authentication.k8s.io/v1alpha1"
    args        = ["eks", "get-token", "--cluster-name", data.aws_eks_cluster.cluster.name]
    command     = "aws"
  }
}

resource "kubernetes_pod" "dashboard" {
  provider = kubernetes.eks

  metadata {
    name = "dashboard"
    annotations = {
      "consul.hashicorp.com/connect-service-upstreams" = "counting:9001:dc2"
    }
    labels = {
      "app" = "dashboard"
    }
  }

  spec {
    container {
      image = "hashicorp/dashboard-service:0.0.4"
      name  = "dashboard"

      env {
        name  = "COUNTING_SERVICE_URL"
        value = "http://localhost:9001"
      }

      port {
        container_port = 9002
        name           = "http"
      }
    }
  }
}

resource "kubernetes_service" "dashboard" {
  provider = kubernetes.eks

  metadata {
    name      = "dashboard-service-load-balancer"
    namespace = "default"
    labels = {
      "app" = "dashboard"
    }
  }

  spec {
    selector = {
      "app" = "dashboard"
    }
    port {
      port        = 80
      target_port = 9002
    }

    type             = "LoadBalancer"
    load_balancer_ip = ""
  }
}

variable "aws_access_key_id" {
  description = "AWS Access Key ID"
}

variable "aws_secret_access_key" {
  description = "AWS Secret Access Key"
}

resource "helm_release" "jenkins" {
  name       = "jenkins"
  repository = "https://charts.jenkins.io"
  chart      = "jenkins"
  # version    = "4.2.17"
  version = "4.11.0"
  namespace  = "jenkins"
  timeout    = 600
  values = [
    file("values.yaml"),
    <<EOF
jenkinsaws:
  awsaccesskey: ${var.aws_access_key_id}
  awssecretkey: ${var.aws_secret_access_key}
EOF
  ]
}

resource "kubernetes_namespace" "jenkins" {
  metadata {
    name = "jenkins"

    labels = {
      name        = "jenkins"
      description = "jenkins"
    }
  }
}

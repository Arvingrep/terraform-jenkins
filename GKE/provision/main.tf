terraform {
    cloud {
        organization = "2up"
        workspaces {
            name = "terraform-jenkins-GKE-provision"
        }
    }
}
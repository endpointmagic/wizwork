provider "kubernetes" {
    config_path    = "~/.kube/config"
    config_context = "docker-desktop"
}

module "tasky_app" {
    source = "../../modules/services/tasky-app"

    name           = "tasky-app"
    image          = "urkl/wizwork:2"
    replicas       = 2
    container_port = 8080
}
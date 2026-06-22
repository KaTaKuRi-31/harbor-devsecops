# Les providers ciblent le cluster k3d local via le contexte kubeconfig.
# (kubeconfig par défaut : ~/.kube/config — contexte "k3d-harbor")
provider "kubernetes" {
  config_path    = var.kubeconfig_path
  config_context = var.kube_context
}

provider "helm" {
  kubernetes {
    config_path    = var.kubeconfig_path
    config_context = var.kube_context
  }
}

variable "kubeconfig_path" {
  description = "Chemin du fichier kubeconfig."
  type        = string
  default     = "~/.kube/config"
}

variable "kube_context" {
  description = "Contexte kubeconfig du cluster k3d."
  type        = string
  default     = "k3d-harbor"
}

variable "harbor_namespace" {
  description = "Namespace de déploiement de Harbor."
  type        = string
  default     = "harbor"
}

variable "monitoring_namespace" {
  description = "Namespace de la stack d'observabilité (Prometheus/Grafana)."
  type        = string
  default     = "monitoring"
}

variable "harbor_chart_version" {
  description = "Version du chart Helm Harbor (https://helm.goharbor.io)."
  type        = string
  default     = "1.16.0"
}

variable "kps_chart_version" {
  description = "Version du chart Helm kube-prometheus-stack."
  type        = string
  default     = "65.5.1"
}

variable "harbor_http_node_port" {
  description = "NodePort HTTP exposant Harbor sur l'hôte (mappé par k3d)."
  type        = number
  default     = 30002
}

variable "harbor_external_url" {
  description = "URL externe de Harbor (doit correspondre au port mappé par k3d)."
  type        = string
  default     = "http://localhost:30002"
}

variable "prometheus_node_port" {
  description = "NodePort exposant l'UI Prometheus."
  type        = number
  default     = 30090
}

variable "grafana_node_port" {
  description = "NodePort exposant l'UI Grafana."
  type        = number
  default     = 30091
}

variable "harbor_admin_password" {
  description = "Mot de passe de l'administrateur Harbor."
  type        = string
  sensitive   = true
  default     = "Harbor12345"
}

variable "grafana_admin_password" {
  description = "Mot de passe de l'administrateur Grafana."
  type        = string
  sensitive   = true
  default     = "admin"
}

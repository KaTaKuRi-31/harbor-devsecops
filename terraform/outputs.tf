output "harbor_url" {
  description = "URL de l'interface et de l'API Harbor."
  value       = var.harbor_external_url
}

output "harbor_admin_user" {
  description = "Identifiant administrateur Harbor."
  value       = "admin"
}

output "prometheus_url" {
  description = "URL de l'interface Prometheus."
  value       = "http://localhost:${var.prometheus_node_port}"
}

output "grafana_url" {
  description = "URL de l'interface Grafana."
  value       = "http://localhost:${var.grafana_node_port}"
}

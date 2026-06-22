# Dashboard Grafana « Harbor — Registre & CVE » provisionné via ConfigMap.
# Le sidecar Grafana de kube-prometheus-stack découvre les ConfigMap portant
# le label grafana_dashboard=1 (searchNamespace=ALL) et les charge.
resource "kubernetes_config_map" "harbor_dashboard" {
  metadata {
    name      = "harbor-registry-cve-dashboard"
    namespace = kubernetes_namespace.monitoring.metadata[0].name
    labels = {
      grafana_dashboard = "1"
    }
  }
  data = {
    "harbor-dashboard.json" = file("${path.module}/../grafana/harbor-dashboard.json")
  }

  depends_on = [helm_release.kube_prometheus_stack]
}

# =====================================================================
#  Déploiement IaC : Harbor + observabilité sur k3s (k3d), via Helm.
#  - kube-prometheus-stack : Prometheus (Operator + CRD ServiceMonitor),
#    Grafana, kube-state-metrics, node-exporter.
#  - Harbor : registre d'images avec scanner Trivy intégré, métriques
#    exposées et ServiceMonitor activé (scrappé par Prometheus).
# =====================================================================

resource "kubernetes_namespace" "monitoring" {
  metadata {
    name = var.monitoring_namespace
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
      purpose                        = "observability"
    }
  }
}

resource "kubernetes_namespace" "harbor" {
  metadata {
    name = var.harbor_namespace
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
      purpose                        = "registry"
    }
  }
}

# --- Observabilité : Prometheus Operator + Grafana ---
resource "helm_release" "kube_prometheus_stack" {
  name       = "kube-prometheus-stack"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  version    = var.kps_chart_version
  namespace  = kubernetes_namespace.monitoring.metadata[0].name

  values = [
    templatefile("${path.module}/values/kube-prometheus-stack.yaml.tftpl", {
      prometheus_node_port = var.prometheus_node_port
      grafana_node_port    = var.grafana_node_port
    })
  ]

  set_sensitive {
    name  = "grafana.adminPassword"
    value = var.grafana_admin_password
  }

  # L'installation des CRD (dont ServiceMonitor) peut être longue.
  timeout = 900
  wait    = true
}

# --- Harbor : registre + scanner Trivy + métriques ---
resource "helm_release" "harbor" {
  name       = "harbor"
  repository = "https://helm.goharbor.io"
  chart      = "harbor"
  version    = var.harbor_chart_version
  namespace  = kubernetes_namespace.harbor.metadata[0].name

  values = [
    templatefile("${path.module}/values/harbor.yaml.tftpl", {
      external_url   = var.harbor_external_url
      http_node_port = var.harbor_http_node_port
    })
  ]

  set_sensitive {
    name  = "harborAdminPassword"
    value = var.harbor_admin_password
  }

  # Le ServiceMonitor de Harbor a besoin de la CRD fournie par la stack Prometheus.
  depends_on = [helm_release.kube_prometheus_stack]

  timeout = 900
  wait    = true
}

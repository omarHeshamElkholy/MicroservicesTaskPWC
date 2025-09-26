resource "kubernetes_namespace" "monitoring" {
  metadata {
    name = "monitoring"
  }

  provider = kubernetes.eks

  depends_on = [kubernetes_config_map_v1.aws_auth]
}

resource "helm_release" "kube_prometheus_stack" {
  name       = "kube-prometheus-stack"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  version    = "60.3.0"
  namespace  = kubernetes_namespace.monitoring.metadata[0].name

  create_namespace = false
  values           = [file("${path.module}/monitoring-values.yaml")]
  wait             = true
  timeout          = 600

  provider = helm.eks

  depends_on = [
    kubernetes_namespace.monitoring,
    kubernetes_config_map_v1.aws_auth
  ]
}

data "kubernetes_service" "grafana" {
  metadata {
    name      = "${helm_release.kube_prometheus_stack.name}-grafana"
    namespace = kubernetes_namespace.monitoring.metadata[0].name
  }

  provider = kubernetes.eks

  depends_on = [helm_release.kube_prometheus_stack]
}

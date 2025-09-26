data "aws_eks_cluster" "this" {
  name = module.k8s_cluster.cluster_name

  depends_on = [module.k8s_cluster]
}

data "aws_eks_cluster_auth" "this" {
  name = module.k8s_cluster.cluster_name

  depends_on = [module.k8s_cluster]
}

locals {
  aws_auth_roles = [
    {
      rolearn  = module.k8s_cluster.node_role_arn
      username = "system:node:{{EC2PrivateDNSName}}"
      groups   = ["system:bootstrappers", "system:nodes"]
    },
    {
      rolearn  = module.ci_cd.codebuild_role_arn
      username = "codebuild"
      groups   = ["system:masters"]
    }
  ]
}

resource "kubernetes_config_map_v1" "aws_auth" {
  metadata {
    name      = "aws-auth"
    namespace = "kube-system"
  }

  data = {
    mapRoles = yamlencode(local.aws_auth_roles)
  }

  provider = kubernetes.eks

  depends_on = [
    module.k8s_cluster,
    module.ci_cd
  ]
}

module "k8s_cluster" {
  source = "./k8s-cluster"

  aws_region     = var.aws_region
  cluster_name   = var.cluster_name
  node_count     = var.node_count
  instance_types = var.instance_types
  volume_size    = var.volume_size
}

module "ci_cd" {
  source = "./ci-cd"

  aws_region          = var.aws_region
  project_name        = var.project_name
  ecr_repository_name = var.ecr_repository_name
  eks_cluster_name    = var.cluster_name

  github_repo_url = var.github_repo_url
  github_branch   = var.github_branch
  github_owner    = var.github_owner
  github_repo     = var.github_repo
}


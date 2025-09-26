output "cluster_name" {
  value       = module.k8s_cluster.cluster_name
  description = "EKS cluster name"
}

output "cluster_endpoint" {
  value       = try(module.k8s_cluster.cluster_endpoint, null)
  description = "EKS cluster endpoint"
}

output "ecr_repository_url" {
  value       = module.ci_cd.ecr_repository_url
  description = "ECR repository URL"
}

output "codebuild_project_name" {
  value       = module.ci_cd.codebuild_project_name
  description = "CodeBuild project name"
}

// Webhook outputs removed; webhook will be configured manually

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
  default     = "microservices-cluster"
}

variable "node_count" {
  description = "Number of worker nodes"
  type        = number
  default     = 3
}

variable "instance_types" {
  description = "EC2 instance types for worker nodes"
  type        = list(string)
  default     = ["t3.small"]
}

variable "volume_size" {
  description = "Node volume size in GB"
  type        = number
  default     = 20
}

variable "project_name" {
  description = "CI/CD project name"
  type        = string
  default     = "microservices-cicd"
}

variable "ecr_repository_name" {
  description = "ECR repository name"
  type        = string
  default     = "microservices-app"
}

variable "github_repo_url" {
  description = "GitHub repository URL"
  type        = string
  default     = "https://github.com/omarHeshamElkholy/MicroservicesTaskPWC.git"
}

variable "github_branch" {
  description = "Branch to trigger builds"
  type        = string
  default     = "main"
}

variable "github_owner" {
  description = "GitHub repository owner"
  type        = string
  default     = "omarHeshamElkholy"
}

variable "github_repo" {
  description = "GitHub repository name"
  type        = string
  default     = "MicroservicesTaskPWC"
}

variable "tf_state_bucket" {
  description = "S3 bucket name for Terraform state"
  type        = string
  default     = "tfbackendz3"
}

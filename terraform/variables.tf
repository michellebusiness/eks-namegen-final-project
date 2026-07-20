variable "aws_region" {
  description = "AWS region used by the project"
  type        = string
  default     = "eu-central-1"
}

variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
  default     = "namegen"
}

variable "cluster_name" {
  description = "Amazon EKS cluster name"
  type        = string
  default     = "namegen-eks-auto"
}

variable "github_owner" {
  description = "GitHub repository owner"
  type        = string
  default     = "michellebusiness"
}

variable "github_repository" {
  description = "GitHub repository name"
  type        = string
  default     = "eks-namegen-final-project"
}
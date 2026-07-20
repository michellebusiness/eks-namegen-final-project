output "aws_region" {
  description = "AWS region used by the project"
  value       = var.aws_region
}

output "vpc_id" {
  description = "ID of the project VPC"
  value       = module.vpc.vpc_id
}

output "private_subnet_ids" {
  description = "Private subnet IDs used by EKS"
  value       = module.vpc.private_subnets
}

output "cluster_name" {
  description = "Amazon EKS cluster name"
  value       = aws_eks_cluster.namegen.name
}

output "cluster_endpoint" {
  description = "Amazon EKS API endpoint"
  value       = aws_eks_cluster.namegen.endpoint
}

output "ecr_repository_url" {
  description = "Amazon ECR repository URL"
  value       = aws_ecr_repository.namegen.repository_url
}

output "github_actions_role_arn" {
  description = "IAM role assumed by GitHub Actions through OIDC"
  value       = aws_iam_role.github_actions.arn
}
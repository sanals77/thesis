output "api_repository_url" {
  description = "URL of the ECR repository for API service"
  value       = aws_ecr_repository.api_service.repository_url
}

output "api_repository_arn" {
  description = "ARN of the ECR repository for API service"
  value       = aws_ecr_repository.api_service.arn
}

output "worker_repository_url" {
  description = "URL of the ECR repository for Worker service"
  value       = aws_ecr_repository.worker_service.repository_url
}

output "worker_repository_arn" {
  description = "ARN of the ECR repository for Worker service"
  value       = aws_ecr_repository.worker_service.arn
}

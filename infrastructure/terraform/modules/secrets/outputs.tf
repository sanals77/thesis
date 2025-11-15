output "app_secrets_arn" {
  description = "ARN of application secrets"
  value       = aws_secretsmanager_secret.app_secrets.arn
}

output "secrets_access_policy_arn" {
  description = "ARN of secrets access policy"
  value       = aws_iam_policy.secrets_access.arn
}

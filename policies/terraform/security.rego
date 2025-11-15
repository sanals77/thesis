# Terraform Security Policies for Infrastructure as Code
# These policies validate Terraform plans before deployment

package terraform.security

import future.keywords.contains
import future.keywords.if
import future.keywords.in

# Default deny
default allow = false

# Allow if all checks pass
allow {
    count(deny) == 0
}

# Collect all violations
deny[msg] {
    check_encrypted_storage
    msg := "Violation: Unencrypted storage detected"
}

deny[msg] {
    check_public_access
    msg := "Violation: Public access to sensitive resources detected"
}

deny[msg] {
    check_security_groups
    msg := "Violation: Overly permissive security group rules detected"
}

deny[msg] {
    check_iam_permissions
    msg := "Violation: Excessive IAM permissions detected"
}

# Check: All storage must be encrypted
check_encrypted_storage {
    some resource in input.resource_changes
    resource.type == "aws_db_instance"
    not resource.change.after.storage_encrypted
}

check_encrypted_storage {
    some resource in input.resource_changes
    resource.type == "aws_ebs_volume"
    not resource.change.after.encrypted
}

check_encrypted_storage {
    some resource in input.resource_changes
    resource.type == "aws_s3_bucket"
    # Check if encryption is not configured
    not has_s3_encryption(resource)
}

# Check: No public access to databases or S3 buckets
check_public_access {
    some resource in input.resource_changes
    resource.type == "aws_db_instance"
    resource.change.after.publicly_accessible == true
}

check_public_access {
    some resource in input.resource_changes
    resource.type == "aws_s3_bucket_public_access_block"
    resource.change.after.block_public_acls == false
}

# Check: Security groups should not allow unrestricted access
check_security_groups {
    some resource in input.resource_changes
    resource.type == "aws_security_group"
    some rule in resource.change.after.ingress
    rule.cidr_blocks[_] == "0.0.0.0/0"
    rule.from_port == 0
    rule.to_port == 0
}

check_security_groups {
    some resource in input.resource_changes
    resource.type == "aws_security_group"
    some rule in resource.change.after.ingress
    rule.cidr_blocks[_] == "0.0.0.0/0"
    is_sensitive_port(rule.from_port)
}

# Check: IAM roles should not have wildcard permissions
check_iam_permissions {
    some resource in input.resource_changes
    resource.type == "aws_iam_policy"
    policy := json.unmarshal(resource.change.after.policy)
    some statement in policy.Statement
    statement.Effect == "Allow"
    statement.Action[_] == "*"
    statement.Resource == "*"
}

# Helper: Check if S3 bucket has encryption
has_s3_encryption(resource) {
    resource.change.after.server_side_encryption_configuration
}

# Helper: Identify sensitive ports
is_sensitive_port(port) {
    sensitive_ports := [22, 3389, 3306, 5432, 6379, 27017]
    port == sensitive_ports[_]
}

# Additional checks for compliance

# Check: VPC flow logs should be enabled
deny[msg] {
    check_vpc_flow_logs
    msg := "Violation: VPC Flow Logs not enabled"
}

check_vpc_flow_logs {
    some vpc in input.resource_changes
    vpc.type == "aws_vpc"
    not has_flow_logs(vpc.address)
}

has_flow_logs(vpc_address) {
    some resource in input.resource_changes
    resource.type == "aws_flow_log"
    contains(resource.change.after.vpc_id, vpc_address)
}

# Check: EKS cluster logging should be enabled
deny[msg] {
    check_eks_logging
    msg := "Violation: EKS cluster logging not fully enabled"
}

check_eks_logging {
    some resource in input.resource_changes
    resource.type == "aws_eks_cluster"
    count(resource.change.after.enabled_cluster_log_types) < 5
}

# Check: RDS should have backup retention
deny[msg] {
    check_rds_backups
    msg := "Violation: RDS backup retention period too short"
}

check_rds_backups {
    some resource in input.resource_changes
    resource.type == "aws_db_instance"
    resource.change.after.backup_retention_period < 7
}

# Check: Tags are required for all resources
deny[msg] {
    check_required_tags
    msg := sprintf("Violation: Required tags missing for resource: %v", [input.resource_changes[_].address])
}

check_required_tags {
    some resource in input.resource_changes
    resource.change.actions[_] == "create"
    not has_required_tags(resource)
}

has_required_tags(resource) {
    required_tags := ["Environment", "Project", "ManagedBy"]
    tags := resource.change.after.tags
    all_present := [tag | tag := required_tags[_]; tags[tag]]
    count(all_present) == count(required_tags)
}

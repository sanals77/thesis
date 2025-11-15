# Terraform Cost Optimization Policies
# Validate resource sizing and cost-effective configurations

package terraform.cost

import future.keywords.if
import future.keywords.in

default allow = true

# Warnings for cost optimization (not blocking)
warn[msg] {
    check_instance_sizes
    msg := "Warning: Large instance types detected - consider right-sizing"
}

warn[msg] {
    check_unused_resources
    msg := "Warning: Potentially unused resources detected"
}

warn[msg] {
    check_storage_optimization
    msg := "Warning: Storage can be optimized"
}

# Check: Instance sizes should be appropriate
check_instance_sizes {
    some resource in input.resource_changes
    resource.type == "aws_instance"
    is_large_instance(resource.change.after.instance_type)
}

is_large_instance(instance_type) {
    large_instances := ["t3.2xlarge", "t3.xlarge", "m5.2xlarge", "m5.xlarge"]
    instance_type == large_instances[_]
}

# Check: Unused elastic IPs
check_unused_resources {
    some resource in input.resource_changes
    resource.type == "aws_eip"
    not is_eip_associated(resource)
}

is_eip_associated(eip_resource) {
    some resource in input.resource_changes
    resource.type in ["aws_nat_gateway", "aws_instance"]
    contains(resource.change.after, eip_resource.address)
}

# Check: Storage optimization
check_storage_optimization {
    some resource in input.resource_changes
    resource.type == "aws_db_instance"
    resource.change.after.allocated_storage > 100
    not resource.change.after.storage_autoscaling
}

# Check: RDS should use cost-effective instance types for dev/staging
warn[msg] {
    check_rds_instance_cost
    msg := "Warning: Consider using smaller RDS instance for non-production environments"
}

check_rds_instance_cost {
    some resource in input.resource_changes
    resource.type == "aws_db_instance"
    tags := resource.change.after.tags
    tags.Environment in ["dev", "staging"]
    not is_cost_effective_rds(resource.change.after.instance_class)
}

is_cost_effective_rds(instance_class) {
    cost_effective := ["db.t3.micro", "db.t3.small", "db.t4g.micro", "db.t4g.small"]
    instance_class == cost_effective[_]
}

# Check: NAT Gateway optimization
warn[msg] {
    check_nat_gateway_optimization
    msg := "Warning: Multiple NAT Gateways increase costs - consider consolidating for non-production"
}

check_nat_gateway_optimization {
    nat_gateways := [r | r := input.resource_changes[_]; r.type == "aws_nat_gateway"]
    count(nat_gateways) > 1
    some resource in nat_gateways
    tags := resource.change.after.tags
    tags.Environment != "prod"
}

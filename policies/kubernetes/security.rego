# Kubernetes Security Policies
# Validate Kubernetes manifests for security best practices

package kubernetes.security

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
    input.kind == "Deployment"
    not has_security_context
    msg := sprintf("Deployment %v must have securityContext defined", [input.metadata.name])
}

deny[msg] {
    input.kind == "Deployment"
    container := input.spec.template.spec.containers[_]
    not container.securityContext.runAsNonRoot
    msg := sprintf("Container %v must run as non-root user", [container.name])
}

deny[msg] {
    input.kind == "Deployment"
    container := input.spec.template.spec.containers[_]
    not container.securityContext.readOnlyRootFilesystem
    msg := sprintf("Container %v must have read-only root filesystem", [container.name])
}

deny[msg] {
    input.kind == "Deployment"
    container := input.spec.template.spec.containers[_]
    container.securityContext.privileged
    msg := sprintf("Container %v must not run in privileged mode", [container.name])
}

deny[msg] {
    input.kind == "Deployment"
    not has_resource_limits
    msg := sprintf("Deployment %v must have resource limits defined", [input.metadata.name])
}

deny[msg] {
    input.kind == "Deployment"
    not has_liveness_probe
    msg := sprintf("Deployment %v must have liveness probe", [input.metadata.name])
}

deny[msg] {
    input.kind == "Deployment"
    not has_readiness_probe
    msg := sprintf("Deployment %v must have readiness probe", [input.metadata.name])
}

deny[msg] {
    input.kind == "Service"
    input.spec.type == "LoadBalancer"
    not has_allowed_ips
    msg := sprintf("Service %v of type LoadBalancer must restrict source IPs", [input.metadata.name])
}

deny[msg] {
    input.kind in ["Deployment", "StatefulSet", "DaemonSet"]
    not has_pod_security_policy
    msg := sprintf("%v %v must reference a PodSecurityPolicy", [input.kind, input.metadata.name])
}

deny[msg] {
    input.kind == "Deployment"
    container := input.spec.template.spec.containers[_]
    has_latest_tag(container.image)
    msg := sprintf("Container %v must not use 'latest' tag", [container.name])
}

# Helper functions
has_security_context {
    input.spec.template.spec.securityContext
}

has_resource_limits {
    container := input.spec.template.spec.containers[_]
    container.resources.limits
}

has_liveness_probe {
    container := input.spec.template.spec.containers[_]
    container.livenessProbe
}

has_readiness_probe {
    container := input.spec.template.spec.containers[_]
    container.readinessProbe
}

has_allowed_ips {
    input.spec.loadBalancerSourceRanges
}

has_pod_security_policy {
    input.spec.template.metadata.annotations["seccomp.security.alpha.kubernetes.io/pod"]
}

has_latest_tag(image) {
    endswith(image, ":latest")
}

has_latest_tag(image) {
    not contains(image, ":")
}

# Network Policy Requirements
deny[msg] {
    input.kind == "Deployment"
    not has_network_policy
    msg := sprintf("Deployment %v should have an associated NetworkPolicy", [input.metadata.name])
}

has_network_policy {
    # This is a simplified check - in practice, you'd check for matching NetworkPolicy resources
    input.metadata.labels["app"]
}

# Secret Management
deny[msg] {
    input.kind == "Deployment"
    container := input.spec.template.spec.containers[_]
    env := container.env[_]
    is_sensitive_env_var(env.name)
    not env.valueFrom.secretKeyRef
    msg := sprintf("Sensitive environment variable %v in container %v must use secretKeyRef", [env.name, container.name])
}

is_sensitive_env_var(name) {
    sensitive_patterns := ["PASSWORD", "SECRET", "TOKEN", "KEY", "CREDENTIAL"]
    upper_name := upper(name)
    pattern := sensitive_patterns[_]
    contains(upper_name, pattern)
}

# Image Pull Policy
deny[msg] {
    input.kind == "Deployment"
    container := input.spec.template.spec.containers[_]
    not container.imagePullPolicy == "Always"
    not container.imagePullPolicy == "IfNotPresent"
    msg := sprintf("Container %v must have explicit imagePullPolicy", [container.name])
}

# Capability Dropping
deny[msg] {
    input.kind == "Deployment"
    container := input.spec.template.spec.containers[_]
    not has_dropped_capabilities(container)
    msg := sprintf("Container %v must drop unnecessary capabilities", [container.name])
}

has_dropped_capabilities(container) {
    container.securityContext.capabilities.drop
    "ALL" in container.securityContext.capabilities.drop
}

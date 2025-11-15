# Kubernetes Best Practices Policies
# Validate Kubernetes manifests for operational best practices

package kubernetes.bestpractices

import future.keywords.contains
import future.keywords.if
import future.keywords.in

default allow = true

# Warnings for best practices (not blocking)
warn[msg] {
    input.kind == "Deployment"
    input.spec.replicas < 2
    msg := sprintf("Deployment %v should have at least 2 replicas for high availability", [input.metadata.name])
}

warn[msg] {
    input.kind == "Deployment"
    not has_pod_disruption_budget
    msg := sprintf("Deployment %v should have a PodDisruptionBudget", [input.metadata.name])
}

warn[msg] {
    input.kind == "Deployment"
    not has_anti_affinity
    msg := sprintf("Deployment %v should have pod anti-affinity for better distribution", [input.metadata.name])
}

warn[msg] {
    input.kind == "Service"
    input.spec.type == "LoadBalancer"
    msg := sprintf("Service %v uses LoadBalancer - consider using Ingress for cost optimization", [input.metadata.name])
}

warn[msg] {
    input.kind == "Deployment"
    not has_labels
    msg := sprintf("Deployment %v should have standard labels (app, version, component)", [input.metadata.name])
}

warn[msg] {
    input.kind == "Deployment"
    container := input.spec.template.spec.containers[_]
    not container.resources.requests
    msg := sprintf("Container %v should have resource requests defined", [container.name])
}

warn[msg] {
    input.kind == "Deployment"
    not has_hpa
    msg := sprintf("Deployment %v should consider using HorizontalPodAutoscaler", [input.metadata.name])
}

# Helper functions
has_pod_disruption_budget {
    # Simplified check - assumes PDB exists with matching labels
    input.metadata.labels["app"]
}

has_anti_affinity {
    input.spec.template.spec.affinity.podAntiAffinity
}

has_labels {
    labels := input.metadata.labels
    labels["app"]
    labels["version"]
}

has_hpa {
    # Simplified check - would need to validate against HPA resources
    input.spec.replicas
}

# Rolling Update Strategy
warn[msg] {
    input.kind == "Deployment"
    not uses_rolling_update
    msg := sprintf("Deployment %v should use RollingUpdate strategy", [input.metadata.name])
}

uses_rolling_update {
    input.spec.strategy.type == "RollingUpdate"
}

# Health Check Timeouts
warn[msg] {
    input.kind == "Deployment"
    container := input.spec.template.spec.containers[_]
    container.livenessProbe
    not has_proper_probe_settings(container.livenessProbe)
    msg := sprintf("Container %v liveness probe should have reasonable timeout settings", [container.name])
}

has_proper_probe_settings(probe) {
    probe.initialDelaySeconds >= 5
    probe.periodSeconds >= 10
}

# Namespace Usage
warn[msg] {
    input.kind in ["Deployment", "Service", "ConfigMap"]
    not input.metadata.namespace
    msg := sprintf("%v %v should specify a namespace", [input.kind, input.metadata.name])
}

warn[msg] {
    input.kind in ["Deployment", "Service", "ConfigMap"]
    input.metadata.namespace == "default"
    msg := sprintf("%v %v should not use 'default' namespace", [input.kind, input.metadata.name])
}

#!/usr/bin/env python3
"""
Policy Metrics Exporter for OPA Gatekeeper
Exports Prometheus metrics for policy violations and compliance status
"""
from prometheus_client import start_http_server, Gauge, Counter
from kubernetes import client, config
import time
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Prometheus metrics
POLICY_VIOLATIONS = Counter('policy_violations_total', 'Total policy violations', ['policy', 'severity'])
POLICY_VALIDATION_DURATION = Gauge('policy_validation_duration_seconds', 'Policy validation duration', ['policy'])
VULNERABILITY_COUNT = Gauge('vulnerability_count', 'Number of vulnerabilities', ['severity'])
DEPLOYMENT_BLOCKED = Counter('deployment_blocked_total', 'Deployments blocked by policy', ['reason'])
VULNERABILITY_SCAN_STATUS = Gauge('vulnerability_scan_status', 'Vulnerability scan status', ['image'])

def collect_gatekeeper_violations():
    """Collect violations from Gatekeeper constraints and check pods for compliance"""
    try:
        config.load_incluster_config()
    except:
        config.load_kube_config()
    
    custom_api = client.CustomObjectsApi()
    core_api = client.CoreV1Api()
    
    try:
        # Get all constraints
        constraints = custom_api.list_cluster_custom_object(
            group="constraints.gatekeeper.sh",
            version="v1beta1",
            plural="k8srequiredlabels"
        )
        
        violation_count = 0
        
        for constraint in constraints.get('items', []):
            status = constraint.get('status', {})
            violations = status.get('violations', [])
            
            constraint_name = constraint['metadata']['name']
            
            # Count violations from constraint status
            if violations:
                POLICY_VIOLATIONS.labels(
                    policy=constraint_name,
                    severity='warning'
                ).inc(len(violations))
                violation_count += len(violations)
                logger.info(f"Found {len(violations)} violations for {constraint_name}")
            
            # Set validation duration (simulated)
            POLICY_VALIDATION_DURATION.labels(policy=constraint_name).set(0.05)
        
        # Also check pods directly for missing labels (for demonstration)
        pods = core_api.list_pod_for_all_namespaces()
        pods_without_app_label = 0
        
        for pod in pods.items:
            # Skip system pods
            if pod.metadata.namespace in ['kube-system', 'gatekeeper-system', 'monitoring']:
                continue
            
            labels = pod.metadata.labels or {}
            if 'app' not in labels:
                pods_without_app_label += 1
        
        if pods_without_app_label > 0:
            # Increment counter for policy violations
            POLICY_VIOLATIONS.labels(
                policy='require-app-label',
                severity='warning'
            ).inc(pods_without_app_label)
            logger.info(f"Found {pods_without_app_label} pods without app label")
        
        # Set sample vulnerability counts (simulated scanning results)
        VULNERABILITY_COUNT.labels(severity='critical').set(0)
        VULNERABILITY_COUNT.labels(severity='high').set(2)
        VULNERABILITY_COUNT.labels(severity='medium').set(5)
        
        # Simulate some deployments being blocked
        if pods_without_app_label > 0:
            DEPLOYMENT_BLOCKED.labels(reason='missing-required-labels').inc(1)
        
        # Set scan status for images
        VULNERABILITY_SCAN_STATUS.labels(image='api-service').set(1)
        VULNERABILITY_SCAN_STATUS.labels(image='worker-service').set(1)
        
    except Exception as e:
        logger.error(f"Error collecting metrics: {e}")

def main():
    logger.info("Starting Policy Metrics Exporter on port 9091")
    start_http_server(9091)
    
    while True:
        collect_gatekeeper_violations()
        time.sleep(60)  # Collect every minute

if __name__ == '__main__':
    main()

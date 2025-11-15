#!/usr/bin/env python3
"""
Interactive Demonstration Script for Cloud-Native Application
Automates the demonstration of key features including API testing,
metrics visualization, policy enforcement, and infrastructure validation.
"""

import subprocess
import time
import requests
import json
import sys
from datetime import datetime
from colorama import init, Fore, Back, Style

# Initialize colorama for colored output
init(autoreset=True)

class CloudNativeDemo:
    def __init__(self):
        self.api_url = "http://localhost:8080"
        self.grafana_url = "http://localhost:3000"
        self.prometheus_url = "http://localhost:9090"
        
    def print_header(self, text):
        """Print a formatted header"""
        print(f"\n{Back.BLUE}{Fore.WHITE}{'=' * 80}{Style.RESET_ALL}")
        print(f"{Back.BLUE}{Fore.WHITE}{text.center(80)}{Style.RESET_ALL}")
        print(f"{Back.BLUE}{Fore.WHITE}{'=' * 80}{Style.RESET_ALL}\n")
    
    def print_section(self, text):
        """Print a section header"""
        print(f"\n{Fore.CYAN}{'─' * 80}")
        print(f"{Fore.CYAN}{text}")
        print(f"{Fore.CYAN}{'─' * 80}{Style.RESET_ALL}\n")
    
    def print_success(self, text):
        """Print success message"""
        print(f"{Fore.GREEN}✓ {text}{Style.RESET_ALL}")
    
    def print_error(self, text):
        """Print error message"""
        print(f"{Fore.RED}✗ {text}{Style.RESET_ALL}")
    
    def print_info(self, text):
        """Print info message"""
        print(f"{Fore.YELLOW}ℹ {text}{Style.RESET_ALL}")
    
    def run_command(self, command, capture_output=True, shell=True):
        """Execute a shell command"""
        try:
            result = subprocess.run(
                command,
                shell=shell,
                capture_output=capture_output,
                text=True,
                timeout=30
            )
            return result.stdout if capture_output else None
        except subprocess.TimeoutExpired:
            self.print_error(f"Command timed out: {command}")
            return None
        except Exception as e:
            self.print_error(f"Command failed: {e}")
            return None
    
    def check_prerequisites(self):
        """Check if all required tools are available"""
        self.print_header("CHECKING PREREQUISITES")
        
        tools = {
            'kubectl': 'kubectl version --client --short',
            'docker': 'docker --version',
            'aws': 'aws --version'
        }
        
        all_ok = True
        for tool, cmd in tools.items():
            output = self.run_command(cmd)
            if output:
                self.print_success(f"{tool} is installed: {output.strip()}")
            else:
                self.print_error(f"{tool} is NOT installed")
                all_ok = False
        
        return all_ok
    
    def check_cluster_status(self):
        """Check Kubernetes cluster and pod status"""
        self.print_header("KUBERNETES CLUSTER STATUS")
        
        # Check dev namespace
        self.print_section("Dev Namespace Pods")
        output = self.run_command("kubectl get pods -n dev")
        print(output)
        
        # Check monitoring namespace
        self.print_section("Monitoring Namespace Pods")
        output = self.run_command("kubectl get pods -n monitoring")
        print(output)
        
        # Check gatekeeper
        self.print_section("Gatekeeper System Pods")
        output = self.run_command("kubectl get pods -n gatekeeper-system")
        print(output)
        
        # Check services
        self.print_section("Services in Dev Namespace")
        output = self.run_command("kubectl get svc -n dev")
        print(output)
    
    def test_api_endpoints(self):
        """Test API service endpoints"""
        self.print_header("API SERVICE TESTING")
        
        self.print_info("IMPORTANT: You need to port-forward the API service first!")
        print(f"\n{Fore.YELLOW}Open a NEW PowerShell terminal and run:{Style.RESET_ALL}")
        print(f"{Back.YELLOW}{Fore.BLACK}kubectl port-forward -n dev svc/api-service 8080:80{Style.RESET_ALL}\n")
        self.print_info("Keep that terminal open during testing")
        
        response = input(f"\n{Fore.CYAN}Is port-forward running? (yes/no): {Style.RESET_ALL}")
        if response.lower() not in ['yes', 'y']:
            self.print_error("Please start port-forward first and try again")
            return
        
        # Test health endpoint
        self.print_section("1. Testing Health Endpoint")
        try:
            response = requests.get(f"{self.api_url}/health", timeout=5)
            if response.status_code == 200:
                self.print_success(f"Health check passed: {response.json()}")
            else:
                self.print_error(f"Health check failed: {response.status_code}")
        except Exception as e:
            self.print_error(f"Failed to connect to API: {e}")
            return
        
        # Get all items
        self.print_section("2. Getting All Items (GET /api/items)")
        try:
            response = requests.get(f"{self.api_url}/api/items", timeout=5)
            if response.status_code == 200:
                items = response.json()
                self.print_success(f"Retrieved {len(items)} items")
                print(json.dumps(items, indent=2))
            else:
                self.print_error(f"Failed to get items: {response.status_code}")
        except Exception as e:
            self.print_error(f"Request failed: {e}")
        
        # Create a new item
        self.print_section("3. Creating New Item (POST /api/items)")
        new_item = {
            "name": f"Demo Item {datetime.now().strftime('%H:%M:%S')}",
            "description": "Created during live demonstration"
        }
        print(f"{Fore.YELLOW}Request body:{Style.RESET_ALL}")
        print(json.dumps(new_item, indent=2))
        
        try:
            response = requests.post(
                f"{self.api_url}/api/items",
                json=new_item,
                headers={"Content-Type": "application/json"},
                timeout=5
            )
            if response.status_code == 201:
                created_item = response.json()
                self.print_success(f"Item created with ID: {created_item.get('id')}")
                print(json.dumps(created_item, indent=2))
                item_id = created_item.get('id')
            else:
                self.print_error(f"Failed to create item: {response.status_code}")
                item_id = None
        except Exception as e:
            self.print_error(f"Request failed: {e}")
            item_id = None
        
        # Get all items again to show the new one
        self.print_section("4. Verifying New Item (GET /api/items)")
        try:
            response = requests.get(f"{self.api_url}/api/items", timeout=5)
            if response.status_code == 200:
                items = response.json()
                self.print_success(f"Now have {len(items)} items total")
                print(json.dumps(items, indent=2))
            else:
                self.print_error(f"Failed to get items: {response.status_code}")
        except Exception as e:
            self.print_error(f"Request failed: {e}")
        
        # Delete the item
        if item_id:
            self.print_section(f"5. Deleting Item (DELETE /api/items/{item_id})")
            try:
                response = requests.delete(f"{self.api_url}/api/items/{item_id}", timeout=5)
                if response.status_code == 200:
                    self.print_success(f"Item {item_id} deleted successfully")
                else:
                    self.print_error(f"Failed to delete item: {response.status_code}")
            except Exception as e:
                self.print_error(f"Request failed: {e}")
    
    def check_prometheus_metrics(self):
        """Check Prometheus metrics"""
        self.print_header("PROMETHEUS METRICS")
        
        self.print_info("IMPORTANT: You need to port-forward Prometheus first!")
        print(f"\n{Fore.YELLOW}Open a NEW PowerShell terminal and run:{Style.RESET_ALL}")
        print(f"{Back.YELLOW}{Fore.BLACK}kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090{Style.RESET_ALL}\n")
        self.print_info("Keep that terminal open during testing")
        
        response = input(f"\n{Fore.CYAN}Is port-forward running? (yes/no): {Style.RESET_ALL}")
        if response.lower() not in ['yes', 'y']:
            self.print_error("Please start port-forward first and try again")
            return
        
        metrics_to_check = [
            ("api_requests_total", "Total API requests"),
            ("api_request_duration_seconds_bucket", "Request duration histogram"),
            ("api_items_total", "Total items in database"),
            ("policy_violations_total", "Policy violations"),
            ("vulnerability_count", "Vulnerability count")
        ]
        
        for metric, description in metrics_to_check:
            self.print_section(f"Checking: {description} ({metric})")
            try:
                response = requests.get(
                    f"{self.prometheus_url}/api/v1/query",
                    params={"query": metric},
                    timeout=5
                )
                if response.status_code == 200:
                    data = response.json()
                    results = data.get('data', {}).get('result', [])
                    if results:
                        self.print_success(f"Metric found with {len(results)} time series")
                        for result in results[:3]:  # Show first 3
                            labels = result.get('metric', {})
                            value = result.get('value', ['', 'N/A'])[1]
                            print(f"  {Fore.GREEN}{labels}{Style.RESET_ALL} = {value}")
                    else:
                        self.print_info(f"No data for {metric} yet")
                else:
                    self.print_error(f"Failed to query metric: {response.status_code}")
            except Exception as e:
                self.print_error(f"Query failed: {e}")
    
    def demonstrate_policy_enforcement(self):
        """Demonstrate OPA Gatekeeper policy enforcement"""
        self.print_header("POLICY ENFORCEMENT DEMONSTRATION")
        
        # Show constraint templates
        self.print_section("1. Constraint Templates")
        output = self.run_command("kubectl get constrainttemplates")
        print(output)
        
        # Show active constraints
        self.print_section("2. Active Constraints")
        output = self.run_command("kubectl get constraints")
        print(output)
        
        # Show constraint details
        self.print_section("3. Required Labels Constraint Details")
        output = self.run_command("kubectl get k8srequiredlabels require-app-label -o yaml")
        print(output[:1000])  # Show first 1000 chars
        
        # Show pods with violations
        self.print_section("4. Pods Without Required Labels")
        output = self.run_command("kubectl get pods -n dev --show-labels")
        print(output)
        
        # Try to create a non-compliant pod
        self.print_section("5. Testing Policy Enforcement")
        self.print_info("Attempting to create pod WITHOUT required 'app' label...")
        
        test_pod = """
apiVersion: v1
kind: Pod
metadata:
  name: policy-test-violation
  namespace: dev
spec:
  containers:
  - name: nginx
    image: nginx:alpine
"""
        
        print(f"{Fore.YELLOW}Pod manifest:{Style.RESET_ALL}")
        print(test_pod)
        
        result = self.run_command(f'echo "{test_pod}" | kubectl apply -f -')
        if result:
            if "created" in result.lower() or "unchanged" in result.lower():
                self.print_info("Pod created (audit mode - allows but logs violation)")
            else:
                self.print_error("Pod blocked by policy enforcement")
            print(result)
        
        # Create a compliant pod
        self.print_section("6. Creating Compliant Pod")
        self.print_info("Attempting to create pod WITH required 'app' label...")
        
        compliant_pod = """
apiVersion: v1
kind: Pod
metadata:
  name: policy-test-compliant
  namespace: dev
  labels:
    app: demo
spec:
  containers:
  - name: nginx
    image: nginx:alpine
"""
        
        print(f"{Fore.YELLOW}Pod manifest:{Style.RESET_ALL}")
        print(compliant_pod)
        
        result = self.run_command(f'echo "{compliant_pod}" | kubectl apply -f -')
        if result:
            self.print_success("Compliant pod created successfully")
            print(result)
        
        # Cleanup
        self.print_section("7. Cleanup Test Pods")
        self.run_command("kubectl delete pod policy-test-violation -n dev --ignore-not-found=true")
        self.run_command("kubectl delete pod policy-test-compliant -n dev --ignore-not-found=true")
        self.print_success("Test pods cleaned up")
    
    def show_infrastructure(self):
        """Show AWS infrastructure details"""
        self.print_header("AWS INFRASTRUCTURE")
        
        # EKS Cluster
        self.print_section("1. EKS Cluster Information")
        output = self.run_command(
            "aws eks describe-cluster --name cloud-native-app-dev --region us-east-1"
        )
        if output:
            try:
                cluster_data = json.loads(output)
                cluster = cluster_data.get('cluster', {})
                print(f"  Name: {cluster.get('name', 'N/A')}")
                print(f"  Status: {cluster.get('status', 'N/A')}")
                print(f"  Version: {cluster.get('version', 'N/A')}")
                print(f"  Endpoint: {cluster.get('endpoint', 'N/A')}")
                self.print_success("EKS cluster information retrieved")
            except:
                print(output)
        
        # RDS Database
        self.print_section("2. RDS Database Instance")
        output = self.run_command(
            "aws rds describe-db-instances --db-instance-identifier cloud-native-app-dev-postgres --region us-east-1"
        )
        if output:
            try:
                db_data = json.loads(output)
                db = db_data.get('DBInstances', [{}])[0]
                print(f"  Identifier: {db.get('DBInstanceIdentifier', 'N/A')}")
                print(f"  Status: {db.get('DBInstanceStatus', 'N/A')}")
                print(f"  Engine: {db.get('Engine', 'N/A')} {db.get('EngineVersion', '')}")
                print(f"  Endpoint: {db.get('Endpoint', {}).get('Address', 'N/A')}")
                print(f"  Storage: {db.get('AllocatedStorage', 'N/A')} GB")
                self.print_success("RDS database information retrieved")
            except:
                print(output)
        
        # ECR Repositories
        self.print_section("3. ECR Container Repositories")
        output = self.run_command(
            "aws ecr describe-repositories --region us-east-1"
        )
        if output:
            try:
                repos_data = json.loads(output)
                repos = repos_data.get('repositories', [])
                for repo in repos:
                    print(f"  • {repo.get('repositoryName', 'N/A')}")
                    print(f"    URI: {repo.get('repositoryUri', 'N/A')}")
                self.print_success(f"Found {len(repos)} ECR repositories")
            except:
                print(output)
        
        # VPC Information
        self.print_section("4. VPC Configuration")
        output = self.run_command(
            "aws ec2 describe-vpcs --filters Name=tag:Name,Values=cloud-native-app-dev-vpc --region us-east-1"
        )
        if output:
            try:
                vpc_data = json.loads(output)
                vpcs = vpc_data.get('Vpcs', [])
                if vpcs:
                    vpc = vpcs[0]
                    print(f"  VPC ID: {vpc.get('VpcId', 'N/A')}")
                    print(f"  CIDR Block: {vpc.get('CidrBlock', 'N/A')}")
                    print(f"  State: {vpc.get('State', 'N/A')}")
                    self.print_success("VPC information retrieved")
                else:
                    self.print_info("No VPC found with that name")
            except:
                print(output)
    
    def show_scaling_demo(self):
        """Demonstrate autoscaling capabilities"""
        self.print_header("AUTOSCALING DEMONSTRATION")
        
        # Show HPA status
        self.print_section("1. Horizontal Pod Autoscaler Status")
        output = self.run_command("kubectl get hpa -n dev")
        print(output)
        
        # Show current pod count
        self.print_section("2. Current Pod Replicas")
        output = self.run_command("kubectl get deployment api-service -n dev")
        print(output)
        
        # Show HPA details
        self.print_section("3. HPA Configuration Details")
        output = self.run_command("kubectl describe hpa api-service-hpa -n dev")
        print(output)
        
        self.print_info("\nTo trigger scaling, you can generate load with:")
        print(f"{Fore.YELLOW}kubectl run load-generator --image=busybox --rm -it --restart=Never -n dev -- /bin/sh -c 'while true; do wget -q -O- http://api-service/api/items; done'{Style.RESET_ALL}")
    
    def show_security_features(self):
        """Show security features"""
        self.print_header("SECURITY FEATURES")
        
        # Network Policies
        self.print_section("1. Network Policies")
        output = self.run_command("kubectl get networkpolicy -n dev")
        print(output)
        
        self.print_section("2. Network Policy Details")
        output = self.run_command("kubectl describe networkpolicy api-service-network-policy -n dev")
        print(output[:1000])
        
        # Service Accounts
        self.print_section("3. Service Accounts")
        output = self.run_command("kubectl get serviceaccount -n dev")
        print(output)
        
        # RBAC
        self.print_section("4. Role Bindings")
        output = self.run_command("kubectl get rolebindings -n dev")
        print(output)
        
        # Secrets
        self.print_section("5. Secrets (Encrypted)")
        output = self.run_command("kubectl get secrets -n dev")
        print(output)
    
    def open_dashboards(self):
        """Open Grafana dashboards in browser"""
        self.print_header("GRAFANA DASHBOARDS")
        
        self.print_info("To access Grafana dashboards:")
        print(f"{Fore.YELLOW}1. Run: kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80{Style.RESET_ALL}")
        print(f"{Fore.YELLOW}2. Open: http://localhost:3000{Style.RESET_ALL}")
        print(f"{Fore.YELLOW}3. Login: admin / admin123{Style.RESET_ALL}")
        print(f"\n{Fore.CYAN}Available Dashboards:{Style.RESET_ALL}")
        print("  • Application Dashboard - API metrics, response times, resource usage")
        print("  • Policy-as-Code Compliance Dashboard - Policy violations, vulnerabilities")
    
    def run_full_demo(self):
        """Run the complete demonstration"""
        print(f"\n{Back.GREEN}{Fore.BLACK}{' ' * 80}{Style.RESET_ALL}")
        print(f"{Back.GREEN}{Fore.BLACK}{'CLOUD-NATIVE APPLICATION DEMONSTRATION'.center(80)}{Style.RESET_ALL}")
        print(f"{Back.GREEN}{Fore.BLACK}{' ' * 80}{Style.RESET_ALL}")
        print(f"\n{Fore.CYAN}This script will demonstrate all key features of the deployment{Style.RESET_ALL}\n")
        
        # Menu
        while True:
            print(f"\n{Fore.CYAN}{'=' * 80}{Style.RESET_ALL}")
            print(f"{Fore.CYAN}DEMONSTRATION MENU{Style.RESET_ALL}")
            print(f"{Fore.CYAN}{'=' * 80}{Style.RESET_ALL}")
            print(f"\n{Fore.YELLOW}1.{Style.RESET_ALL}  Check Prerequisites")
            print(f"{Fore.YELLOW}2.{Style.RESET_ALL}  Show Cluster Status")
            print(f"{Fore.YELLOW}3.{Style.RESET_ALL}  Test API Endpoints")
            print(f"{Fore.YELLOW}4.{Style.RESET_ALL}  Check Prometheus Metrics")
            print(f"{Fore.YELLOW}5.{Style.RESET_ALL}  Demonstrate Policy Enforcement")
            print(f"{Fore.YELLOW}6.{Style.RESET_ALL}  Show AWS Infrastructure")
            print(f"{Fore.YELLOW}7.{Style.RESET_ALL}  Show Autoscaling Configuration")
            print(f"{Fore.YELLOW}8.{Style.RESET_ALL}  Show Security Features")
            print(f"{Fore.YELLOW}9.{Style.RESET_ALL}  Open Grafana Dashboards (Instructions)")
            print(f"{Fore.YELLOW}10.{Style.RESET_ALL} Run All Demonstrations")
            print(f"{Fore.RED}0.{Style.RESET_ALL}  Exit")
            
            choice = input(f"\n{Fore.CYAN}Enter your choice: {Style.RESET_ALL}")
            
            if choice == "1":
                self.check_prerequisites()
            elif choice == "2":
                self.check_cluster_status()
            elif choice == "3":
                self.test_api_endpoints()
            elif choice == "4":
                self.check_prometheus_metrics()
            elif choice == "5":
                self.demonstrate_policy_enforcement()
            elif choice == "6":
                self.show_infrastructure()
            elif choice == "7":
                self.show_scaling_demo()
            elif choice == "8":
                self.show_security_features()
            elif choice == "9":
                self.open_dashboards()
            elif choice == "10":
                self.check_prerequisites()
                self.check_cluster_status()
                self.show_infrastructure()
                self.demonstrate_policy_enforcement()
                self.show_security_features()
                self.show_scaling_demo()
                self.open_dashboards()
                self.print_success("\nFull demonstration completed!")
            elif choice == "0":
                print(f"\n{Fore.GREEN}Thank you for the demonstration!{Style.RESET_ALL}\n")
                break
            else:
                self.print_error("Invalid choice. Please try again.")
            
            input(f"\n{Fore.CYAN}Press Enter to continue...{Style.RESET_ALL}")

if __name__ == "__main__":
    try:
        demo = CloudNativeDemo()
        demo.run_full_demo()
    except KeyboardInterrupt:
        print(f"\n\n{Fore.YELLOW}Demonstration interrupted by user{Style.RESET_ALL}")
        sys.exit(0)
    except Exception as e:
        print(f"\n{Fore.RED}Error: {e}{Style.RESET_ALL}")
        sys.exit(1)

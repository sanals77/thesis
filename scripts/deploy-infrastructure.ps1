# Infrastructure Deployment Script
# This script deploys the AWS infrastructure using Terraform

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet("dev", "staging", "prod")]
    [string]$Environment = "dev",
    
    [Parameter(Mandatory=$false)]
    [switch]$AutoApprove = $false
)

Write-Host "=== Infrastructure Deployment Script ===" -ForegroundColor Green
Write-Host "Environment: $Environment" -ForegroundColor Cyan
Write-Host ""

# Configuration
$TERRAFORM_DIR = Join-Path $PSScriptRoot "..\infrastructure\terraform"
$POLICIES_DIR = Join-Path $PSScriptRoot "..\policies\terraform"

# Check if Terraform is installed
Write-Host "Checking Terraform installation..." -ForegroundColor Cyan
try {
    $tfVersion = terraform version
    Write-Host "Terraform is installed: $tfVersion" -ForegroundColor Green
} catch {
    Write-Host "ERROR: Terraform is not installed" -ForegroundColor Red
    Write-Host "Download from: https://www.terraform.io/downloads" -ForegroundColor Yellow
    exit 1
}

# Check if OPA is installed
Write-Host "Checking OPA installation..." -ForegroundColor Cyan
try {
    $opaVersion = opa version
    Write-Host "OPA is installed: $opaVersion" -ForegroundColor Green
} catch {
    Write-Host "WARNING: OPA is not installed. Policy validation will be skipped." -ForegroundColor Yellow
    Write-Host "Download from: https://www.openpolicyagent.org/docs/latest/#1-download-opa" -ForegroundColor Yellow
}

# Navigate to Terraform directory
Set-Location $TERRAFORM_DIR

# Initialize Terraform
Write-Host ""
Write-Host "Initializing Terraform..." -ForegroundColor Cyan
terraform init
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Terraform initialization failed" -ForegroundColor Red
    exit 1
}
Write-Host "Terraform initialized successfully" -ForegroundColor Green

# Validate Terraform configuration
Write-Host ""
Write-Host "Validating Terraform configuration..." -ForegroundColor Cyan
terraform validate
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Terraform validation failed" -ForegroundColor Red
    exit 1
}
Write-Host "Terraform configuration is valid" -ForegroundColor Green

# Create Terraform plan
Write-Host ""
Write-Host "Creating Terraform plan..." -ForegroundColor Cyan
terraform plan -var="environment=$Environment" -out=tfplan.binary
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Terraform plan failed" -ForegroundColor Red
    exit 1
}
Write-Host "Terraform plan created successfully" -ForegroundColor Green

# Convert plan to JSON for policy validation
Write-Host ""
Write-Host "Converting plan to JSON for policy validation..." -ForegroundColor Cyan
terraform show -json tfplan.binary | Out-File -FilePath tfplan.json -Encoding utf8
Write-Host "Plan converted to JSON" -ForegroundColor Green

# Validate with OPA policies
Write-Host ""
Write-Host "Validating with OPA policies..." -ForegroundColor Cyan

try {
    # Security policy validation
    Write-Host "Checking security policies..." -ForegroundColor Yellow
    $securityResult = opa eval --data "$POLICIES_DIR\security.rego" --input tfplan.json --format pretty "data.terraform.security.deny"
    
    if ($securityResult -match "true" -or $securityResult -match "violation") {
        Write-Host "WARNING: Security policy violations detected:" -ForegroundColor Yellow
        Write-Host $securityResult -ForegroundColor Yellow
        
        $continue = Read-Host "Do you want to continue anyway? (yes/no)"
        if ($continue -ne "yes") {
            Write-Host "Deployment cancelled" -ForegroundColor Red
            exit 1
        }
    } else {
        Write-Host "Security policies passed" -ForegroundColor Green
    }
    
    # Cost optimization policy validation
    Write-Host "Checking cost optimization policies..." -ForegroundColor Yellow
    $costResult = opa eval --data "$POLICIES_DIR\cost.rego" --input tfplan.json --format pretty "data.terraform.cost.warn"
    
    if ($costResult -match "warning") {
        Write-Host "Cost optimization warnings:" -ForegroundColor Yellow
        Write-Host $costResult -ForegroundColor Yellow
    } else {
        Write-Host "Cost optimization checks passed" -ForegroundColor Green
    }
} catch {
    Write-Host "Policy validation skipped (OPA not available)" -ForegroundColor Yellow
}

# Apply Terraform plan
Write-Host ""
Write-Host "Applying Terraform plan..." -ForegroundColor Cyan

if ($AutoApprove) {
    terraform apply tfplan.binary
} else {
    $confirm = Read-Host "Do you want to apply this plan? (yes/no)"
    if ($confirm -eq "yes") {
        terraform apply tfplan.binary
    } else {
        Write-Host "Deployment cancelled" -ForegroundColor Yellow
        exit 0
    }
}

if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Terraform apply failed" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "=== Infrastructure Deployment Complete ===" -ForegroundColor Green
Write-Host ""

# Display outputs
Write-Host "Terraform Outputs:" -ForegroundColor Cyan
terraform output

# Save outputs to file
Write-Host ""
Write-Host "Saving outputs to file..." -ForegroundColor Cyan
terraform output -json | Out-File -FilePath "terraform-outputs.json" -Encoding utf8
Write-Host "Outputs saved to terraform-outputs.json" -ForegroundColor Green

Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "1. Configure kubectl with: aws eks update-kubeconfig --region us-east-1 --name cloud-native-app-$Environment" -ForegroundColor White
Write-Host "2. Deploy applications using deploy-application.ps1" -ForegroundColor White
Write-Host ""

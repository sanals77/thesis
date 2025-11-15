# AWS Setup Script for Cloud-Native Application
# This script sets up the AWS infrastructure prerequisites

Write-Host "=== AWS Setup Script ===" -ForegroundColor Green
Write-Host "This script will set up AWS prerequisites for the cloud-native application" -ForegroundColor Yellow
Write-Host ""

# Configuration
$AWS_REGION = "us-east-1"
$AWS_ACCOUNT_ID = "537651148488"
$BUCKET_NAME = "sanal-thesis-terraform-state"
$DYNAMODB_TABLE = "terraform-state-locks"

# Check if AWS CLI is installed
Write-Host "Checking AWS CLI installation..." -ForegroundColor Cyan
try {
    $awsVersion = aws --version
    Write-Host "AWS CLI is installed: $awsVersion" -ForegroundColor Green
} catch {
    Write-Host "ERROR: AWS CLI is not installed. Please install it first." -ForegroundColor Red
    Write-Host "Download from: https://aws.amazon.com/cli/" -ForegroundColor Yellow
    exit 1
}

# Check AWS configuration
Write-Host "Checking AWS credentials..." -ForegroundColor Cyan
try {
    $identity = aws sts get-caller-identity --output json | ConvertFrom-Json
    Write-Host "Authenticated as: $($identity.Arn)" -ForegroundColor Green
    Write-Host "Account ID: $($identity.Account)" -ForegroundColor Green
} catch {
    Write-Host "ERROR: AWS credentials not configured" -ForegroundColor Red
    Write-Host "Run 'aws configure' to set up credentials" -ForegroundColor Yellow
    exit 1
}

# Create S3 bucket for Terraform state
Write-Host ""
Write-Host "Creating S3 bucket for Terraform state..." -ForegroundColor Cyan
try {
    $bucketExists = aws s3api head-bucket --bucket $BUCKET_NAME 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "S3 bucket $BUCKET_NAME already exists" -ForegroundColor Yellow
    } else {
        aws s3api create-bucket --bucket $BUCKET_NAME --region $AWS_REGION
        Write-Host "S3 bucket created: $BUCKET_NAME" -ForegroundColor Green
    }
} catch {
    Write-Host "ERROR: Failed to create S3 bucket" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
}

# Enable versioning on S3 bucket
Write-Host "Enabling versioning on S3 bucket..." -ForegroundColor Cyan
try {
    aws s3api put-bucket-versioning --bucket $BUCKET_NAME --versioning-configuration Status=Enabled --region $AWS_REGION
    Write-Host "Versioning enabled on S3 bucket" -ForegroundColor Green
} catch {
    Write-Host "ERROR: Failed to enable versioning" -ForegroundColor Red
}

# Enable encryption on S3 bucket
Write-Host "Enabling encryption on S3 bucket..." -ForegroundColor Cyan
try {
    $tempFile = [System.IO.Path]::GetTempFileName()
    $encryptionConfig = @"
{
    "Rules": [
        {
            "ApplyServerSideEncryptionByDefault": {
                "SSEAlgorithm": "AES256"
            }
        }
    ]
}
"@
    [System.IO.File]::WriteAllText($tempFile, $encryptionConfig, [System.Text.UTF8Encoding]::new($false))
    
    aws s3api put-bucket-encryption --bucket $BUCKET_NAME --region $AWS_REGION `
        --server-side-encryption-configuration file://$tempFile
    
    Remove-Item -Path $tempFile -Force
    Write-Host "Encryption enabled on S3 bucket" -ForegroundColor Green
} catch {
    Write-Host "ERROR: Failed to enable encryption" -ForegroundColor Red
}

# Block public access to S3 bucket
Write-Host "Blocking public access to S3 bucket..." -ForegroundColor Cyan
try {
    aws s3api put-public-access-block --bucket $BUCKET_NAME --region $AWS_REGION `
        --public-access-block-configuration "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"
    Write-Host "Public access blocked on S3 bucket" -ForegroundColor Green
} catch {
    Write-Host "ERROR: Failed to block public access" -ForegroundColor Red
}

# Create DynamoDB table for Terraform state locking
Write-Host ""
Write-Host "Creating DynamoDB table for state locking..." -ForegroundColor Cyan
try {
    $tableExists = aws dynamodb describe-table --table-name $DYNAMODB_TABLE --region $AWS_REGION 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "DynamoDB table $DYNAMODB_TABLE already exists" -ForegroundColor Yellow
    } else {
        aws dynamodb create-table `
            --table-name $DYNAMODB_TABLE `
            --attribute-definitions AttributeName=LockID,AttributeType=S `
            --key-schema AttributeName=LockID,KeyType=HASH `
            --billing-mode PAY_PER_REQUEST `
            --region $AWS_REGION
        Write-Host "DynamoDB table created: $DYNAMODB_TABLE" -ForegroundColor Green
        
        # Wait for table to be active
        Write-Host "Waiting for table to be active..." -ForegroundColor Cyan
        aws dynamodb wait table-exists --table-name $DYNAMODB_TABLE --region $AWS_REGION
        Write-Host "Table is now active" -ForegroundColor Green
    }
} catch {
    Write-Host "ERROR: Failed to create DynamoDB table" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
}

# Verify ECR repositories (will be created by Terraform)
Write-Host ""
Write-Host "Checking ECR repositories..." -ForegroundColor Cyan
$repos = @("cloud-native-app-dev-api-service", "cloud-native-app-dev-worker-service")
foreach ($repo in $repos) {
    try {
        $ecrRepo = aws ecr describe-repositories --repository-names $repo --region $AWS_REGION 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "ECR repository exists: $repo" -ForegroundColor Green
        } else {
            Write-Host "ECR repository will be created by Terraform: $repo" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "ECR repository will be created by Terraform: $repo" -ForegroundColor Yellow
    }
}

# Summary
Write-Host ""
Write-Host "=== Setup Complete ===" -ForegroundColor Green
Write-Host ""
Write-Host "AWS Region: $AWS_REGION" -ForegroundColor Cyan
Write-Host "Account ID: $AWS_ACCOUNT_ID" -ForegroundColor Cyan
Write-Host "S3 Bucket: $BUCKET_NAME" -ForegroundColor Cyan
Write-Host "DynamoDB Table: $DYNAMODB_TABLE" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "1. Navigate to infrastructure/terraform directory" -ForegroundColor White
Write-Host "2. Run 'terraform init' to initialize Terraform" -ForegroundColor White
Write-Host "3. Run 'terraform plan' to see what will be created" -ForegroundColor White
Write-Host "4. Run 'terraform apply' to create infrastructure" -ForegroundColor White
Write-Host ""

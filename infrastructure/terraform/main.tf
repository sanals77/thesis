terraform {
  required_version = ">= 1.5.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  
  # Remote backend for state management
  backend "s3" {
    bucket         = "sanal-thesis-terraform-state"
    key            = "cloud-native-app/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-state-locks"
  }
}

provider "aws" {
  region = var.aws_region
  
  default_tags {
    tags = {
      Project     = "CloudNativeThesis"
      Environment = var.environment
      ManagedBy   = "Terraform"
      Owner       = "SanalThesis"
    }
  }
}

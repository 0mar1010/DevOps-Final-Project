terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

variable "endpoint" {
  type = string
}

provider "aws" {
  region                      = "us-east-1"
  access_key                  = "test"
  secret_key                  = "test"
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true
  s3_use_path_style           = true

  endpoints {
    ec2 = var.endpoint
    s3  = var.endpoint
    iam = var.endpoint
    sts = var.endpoint
  }
}

resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "capstone-vpc"
  }
}

resource "aws_s3_bucket" "artifacts" {
  bucket = "capstone-artifacts"
}

output "vpc_id" {
  value = aws_vpc.main.id
}

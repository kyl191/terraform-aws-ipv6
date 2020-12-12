terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 2.6"
    }
    random = {
      source = "hashicorp/random"
    }
  }
}

provider "aws" {
  region  = "us-west-2"
}

provider "cloudflare" {
  api_token = var.cloudflare_token
}
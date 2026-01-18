terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }

    random = {
      source = "hashicorp/random"
    }
  }
}

provider "aws" {
  region  = "us-west-2"
}

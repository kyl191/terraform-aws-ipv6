terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }

    random = {
      source = "hashicorp/random"
    }
  }
}

provider "aws" {
  region  = "us-west-2"
}

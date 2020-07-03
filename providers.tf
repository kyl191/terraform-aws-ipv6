provider "aws" {
  version = "~> 2.0"
  region  = "us-west-2"
}

provider "cloudflare" {
  api_token = var.cloudflare_token
  version   = "~> 2.6"
}
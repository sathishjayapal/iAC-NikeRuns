terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
    tls = {
      source = "hashicorp/tls"
    }
    local = {
      source = "hashicorp/local"
    }
  }
}

provider "aws" {
  region = "us-east-1"

  default_tags {
    tags = {
      "Owner"       = "sathish"
      "Environment" = "dev"
      "Project"     = "config-server"
    }
  }
}

terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }

}
provider "aws" {
  region  = "us-east-1"
  profile = "acg-sandbox"
  default_tags {
    tags = {
      "Owner" = "date_11424"
      "Environment" = "dev"
      "Project" = "config-server"
    }
  }
}

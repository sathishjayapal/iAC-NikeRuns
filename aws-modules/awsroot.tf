terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }

}
provider "aws" {
  default_tags {
    tags = {
      "Owner" = "date_11424"
      "Environment" = "dev"
      "Project" = "config-server"
    }
  }
}

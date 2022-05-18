terraform {
  required_version = "~> 1.0.0"

  backend "s3" {
    # aws s3 --prifile kiba mb s3://kiba-infra-krishali
    key = "tf-state.json"
    region = "eu-west-1"
    bucket = "kiba-infra-krishali"
    profile = "kiba"
    encrypt = true
  }
  required_providers {
    aws = {
      version = "3.32.0"
    }
  }
}

provider "aws" {
  region = "eu-west-1"
  profile = "kiba"
}

locals {
  project = "krishali"
}

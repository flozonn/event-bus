provider "aws" {
  region  = "eu-west-3"
  profile = "your-profile-name"
}

data "aws_caller_identity" "current" {}
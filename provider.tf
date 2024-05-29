provider "aws" {
  region  = "eu-west-3"
  profile = "playground_archi"
}

data "aws_caller_identity" "current" {}
terraform {
  backend "s3" {
    bucket         = "team-playground-archi-terraform-backend"
    key            = "event-bus-load-test/terraform.tfstate"
    region         = "eu-west-3"
    dynamodb_table = "team-playground-archi-terraform-backend-dynamodb-table"
    encrypt        = true
    kms_key_id     = "02e30da0-fa25-4f5c-b190-bd7b8765c94f"
  }
}
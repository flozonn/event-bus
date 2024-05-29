
resource "aws_dynamodb_table" "processed_events1" {
  billing_mode = "PAY_PER_REQUEST"
  name         = "processed_events1"
  hash_key     = "eventId"
  range_key    = "target"
  attribute {
    name = "eventId"
    type = "S"
  }
  attribute {
    name = "target"
    type = "S"
  }

}


resource "aws_dynamodb_table" "processed_events2" {
  billing_mode = "PAY_PER_REQUEST"
  name         = "processed_events2"
  hash_key     = "eventId"
  range_key    = "target"
  attribute {
    name = "eventId"
    type = "S"
  }
  attribute {
    name = "target"
    type = "S"
  }

}


resource "aws_dynamodb_table" "processed_events3" {
  billing_mode = "PAY_PER_REQUEST"
  name         = "processed_events3"
  hash_key     = "eventId"
  range_key    = "target"
  attribute {
    name = "eventId"
    type = "S"
  }
  attribute {
    name = "target"
    type = "S"
  }

}
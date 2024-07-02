module "lambda31" {
  source    = "genstackio/lambda/aws"
  name      = "olf-bus-target3-1"
  file      = "${path.module}/olf-bus-target3.1/olf-bus-target3.zip"
  file_hash = filebase64sha256("${path.module}/olf-bus-target3.1/olf-bus-target3.zip")
  runtime   = "provided.al2"
  handler   = "index.php"
  layers    = ["arn:aws:lambda:eu-west-3:534081306603:layer:php-81:81"]
  policy_statements = [
    {
      "effect" : "Allow",
      "actions" : [
        "sqs:*",
      ],
      "resources" : [aws_sqs_queue.event_bus_target3_queue.arn]
    },
    {
      "effect" : "Allow",
      "actions" : [
        "kms:Encrypt",
        "kms:Decrypt"
      ],
      "resources" : [aws_kms_key.encrypt_decrypt.arn]
    },
    {
      "effect" : "Allow",
      "actions" : [
        "dynamodb:PutItem",
        "dynamodb:Get*",
        "dynamodb:Update*"
      ],
      "resources" : [aws_dynamodb_table.processed_events3.arn]
    },
    {
      "effect" : "Allow",
      "actions" : [
        "xray:*",

        "logs:*",
        "lambda:GetLayerVersion"
      ],
      "resources" : ["*"]
    }
  ]
  variables = {
  }

}




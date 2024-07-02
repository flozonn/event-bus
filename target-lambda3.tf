module "lambda3" {
  source    = "genstackio/lambda/aws"
  name      = "olf-bus-target3"
  file      = "${path.module}/olf-bus-target3/olf-bus-target3.zip"
  file_hash = filebase64sha256("${path.module}/olf-bus-target3/olf-bus-target3.zip")
  runtime   = "provided.al2"
  handler   = "index.php"
  timeout   = 35
  layers    = ["arn:aws:lambda:eu-west-3:403367587399:layer:php-81:242", "arn:aws:lambda:eu-west-3:901920570463:layer:aws-otel-collector-amd64-ver-0-68-0:1", "arn:aws:lambda:eu-west-3:403367587399:layer:grpc-php-81:16"]
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
    "OPENTELEMETRY_COLLECTOR_CONFIG_FILE" = "/var/task/collector.yaml"
  }

}



resource "aws_lambda_permission" "allow_sqs3" {
  statement_id  = "AllowExecutionFromSQS"
  action        = "lambda:InvokeFunction"
  function_name = module.lambda3.arn

  principal = "sqs.amazonaws.com"

  source_arn = aws_sqs_queue.event_bus_target3_queue.arn
}



resource "aws_lambda_event_source_mapping" "event_source_mapping3" {
  event_source_arn = aws_sqs_queue.event_bus_target3_queue.arn
  function_name    = module.lambda3.name
  batch_size       = 1
  scaling_config {
    maximum_concurrency = 2
  }
}



// basic lambda role 

resource "aws_iam_role" "lambda_role3" {
  name = "lambda_execution_role3"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "lambda.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}


resource "aws_iam_policy" "r_sqs_read_policy3" {
  name        = "sqs-poll-messages3"
  description = "Policy for allowing read access to the events queue"
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : [
          "sqs:*",
        ],
        "Resource" : [aws_sqs_queue.event_bus_target3_queue.arn]
      },
      {
        "Effect" : "Allow",
        "Action" : [
          "kms:Encrypt",
          "kms:Decrypt"
        ],
        "Resource" : aws_kms_key.encrypt_decrypt.arn
      }
    ]
  })
}

resource "aws_iam_policy" "ddb_rw_policy3" {
  name        = "ddb_rw_policy3"
  description = "Policy for allowing read access to the events queue"
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : [
          "dynamodb:PutItem",
          "dynamodb:Get*",
          "dynamodb:Update*"
        ],
        "Resource" : aws_dynamodb_table.processed_events3.arn
      }
    ]
    }
  )
}


resource "aws_iam_policy" "xray_w_policy3" {
  name        = "xray_w_policy3"
  description = "Policy for allowing writing segments to xray"
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : [
          "xray:PutTraceSegments",
          "xray:PutTelemetryRecords",
          "xray:PutTraceSegments",
          "xray:PutTelemetryRecords",
          "xray:GetSamplingRules",
          "xray:GetSamplingTargets",
          "xray:GetSamplingStatisticSummaries",
          "logs:*"
        ],
        "Resource" : "*"
      }
    ]
    }
  )
}



resource "aws_iam_role_policy_attachment" "r_logs_attachment3" {
  role       = aws_iam_role.lambda_role3.name
  policy_arn = aws_iam_policy.r_sqs_read_policy3.arn
}

resource "aws_iam_role_policy_attachment" "ddb_rw_policys_attachment3" {
  role       = aws_iam_role.lambda_role3.name
  policy_arn = aws_iam_policy.ddb_rw_policy3.arn
}

resource "aws_iam_role_policy_attachment" "xray_w_policys_attachment3" {
  role       = aws_iam_role.lambda_role3.name
  policy_arn = aws_iam_policy.xray_w_policy2.arn
}
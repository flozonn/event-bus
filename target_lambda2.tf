resource "aws_lambda_function" "bus_target2" {
  function_name    = "olf-bus-target2"
  handler          = "index.handler"
  runtime          = "nodejs20.x"
  filename         = "${path.module}/olf-bus-target/olf-bus-target.zip"
  source_code_hash = filebase64sha256("${path.module}/olf-bus-target/olf-bus-target.zip")
  role             = aws_iam_role.lambda_role2.arn
  timeout          = 15
  tracing_config {
    mode = "Active"
  }
  environment {
    variables = {
      TABLE_NAME = "processed_events2"
    }
  }
}

resource "aws_lambda_permission" "allow_sqs2" {
  statement_id  = "AllowExecutionFromSQS"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.bus_target2.arn

  principal = "sqs.amazonaws.com"

  source_arn = aws_sqs_queue.event_bus_target2_queue.arn
}



resource "aws_lambda_event_source_mapping" "event_source_mapping2" {
  event_source_arn = aws_sqs_queue.event_bus_target2_queue.arn
  function_name    = aws_lambda_function.bus_target2.function_name
  batch_size       = 1
  scaling_config {
    maximum_concurrency = 2
  }
}



// basic lambda role 

resource "aws_iam_role" "lambda_role2" {
  name = "lambda_execution_role2"
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


resource "aws_iam_policy" "r_sqs_read_policy2" {
  name        = "sqs-poll-messages2"
  description = "Policy for allowing read access to the events queue"
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : [
          "sqs:*",
        ],
        "Resource" : [aws_sqs_queue.event_bus_target2_queue.arn]
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

resource "aws_iam_policy" "ddb_rw_policy2" {
  name        = "ddb_rw_policy2"
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
        "Resource" : aws_dynamodb_table.processed_events2.arn
      }
    ]
    }
  )
}


resource "aws_iam_policy" "xray_w_policy2" {
  name        = "xray_w_policy2"
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



resource "aws_iam_role_policy_attachment" "r_logs_attachment2" {
  role       = aws_iam_role.lambda_role2.name
  policy_arn = aws_iam_policy.r_sqs_read_policy2.arn
}

resource "aws_iam_role_policy_attachment" "ddb_rw_policys_attachment2" {
  role       = aws_iam_role.lambda_role2.name
  policy_arn = aws_iam_policy.ddb_rw_policy2.arn
}

resource "aws_iam_role_policy_attachment" "xray_w_policys_attachment2" {
  role       = aws_iam_role.lambda_role2.name
  policy_arn = aws_iam_policy.xray_w_policy2.arn
}
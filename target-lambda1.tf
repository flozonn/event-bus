resource "aws_lambda_function" "bus_target" {
  function_name    = "olf-bus-target"
  handler          = "index.handler"
  runtime          = "nodejs20.x"
  filename         = "${path.module}/olf-bus-target/olf-bus-target.zip"
  source_code_hash = filebase64sha256("${path.module}/olf-bus-target/olf-bus-target.zip")
  role             = aws_iam_role.lambda_role.arn
  timeout          = 15
  tracing_config {
    mode = "Active"
  }
  environment {
    variables = {
      TABLE_NAME = "processed_events1"
    }
  }
}

resource "aws_lambda_permission" "allow_sqs" {
  statement_id  = "AllowExecutionFromSQS"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.bus_target.arn

  principal = "sqs.amazonaws.com"

  source_arn = aws_sqs_queue.event_bus_target_queue.arn
}



resource "aws_lambda_event_source_mapping" "event_source_mapping" {
  event_source_arn = aws_sqs_queue.event_bus_target_queue.arn
  function_name    = aws_lambda_function.bus_target.function_name
  batch_size       = 1
  scaling_config {
    maximum_concurrency = 2
  }
}



// basic lambda role 

resource "aws_iam_role" "lambda_role" {
  name = "lambda_execution_role"
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


resource "aws_iam_policy" "r_sqs_read_policy" {
  name        = "sqs-poll-messages"
  description = "Policy for allowing read access to the events queue"
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : [
          "sqs:*",
        ],
        "Resource" : [aws_sqs_queue.event_bus_target_queue.arn]
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

resource "aws_iam_policy" "ddb_rw_policy" {
  name        = "ddb_rw_policy"
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
        "Resource" : aws_dynamodb_table.processed_events1.arn
      }
    ]
    }
  )
}


resource "aws_iam_policy" "xray_w_policy" {
  name        = "xray_w_policy"
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





resource "aws_iam_role_policy_attachment" "r_logs_attachment" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.r_sqs_read_policy.arn
}

resource "aws_iam_role_policy_attachment" "ddb_rw_policys_attachment" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.ddb_rw_policy.arn
}

resource "aws_iam_role_policy_attachment" "xray_w_policys_attachment" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.xray_w_policy.arn
}
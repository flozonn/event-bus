resource "aws_lambda_function" "bus_producer" {
  function_name    = "olf-bus-producer"
  handler          = "index.handler"
  runtime          = "nodejs20.x"
  filename         = "${path.module}/olf-bus-producer/olf-bus-producer.zip"
  source_code_hash = filebase64sha256("${path.module}/olf-bus-producer/olf-bus-producer.zip")
  role             = aws_iam_role.lambda_producer_role.arn
  timeout          = 15
  tracing_config {
    mode = "Active"
  }

}



// basic lambda role 

resource "aws_iam_role" "lambda_producer_role" {
  name = "lambda_execution_producer_role"
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




resource "aws_iam_policy" "send_to_bus_policy" {
  name        = "event-send-messages"
  description = "Policy for allowing sending messages to bus"
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Sid" : "Stmt1713429943865",
        "Action" : [
          "events:PutEvents"
        ],
        "Effect" : "Allow",
        "Resource" : "*"
      },
      {
        "Effect" : "Allow",
        "Action" : [
          "kms:Encrypt",
          "kms:Decrypt"
        ],
        "Resource" : "*"
      }
    ]
  })
}



resource "aws_iam_policy_attachment" "lambda_execution_producer_policy_attachment" {
  name       = "lambda_execution_producer_policy_attachment"
  roles      = [aws_iam_role.lambda_producer_role.name]
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}



resource "aws_iam_role_policy_attachment" "xray_w_producer_attachment" {
  role       = aws_iam_role.lambda_producer_role.name
  policy_arn = aws_iam_policy.xray_w_policy.arn
}

resource "aws_iam_role_policy_attachment" "putenvents_producer_attachment" {
  role       = aws_iam_role.lambda_producer_role.name
  policy_arn = aws_iam_policy.send_to_bus_policy.arn
}
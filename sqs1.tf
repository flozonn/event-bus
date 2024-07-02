resource "aws_sqs_queue" "event_bus_target_queue" {
  name                       = "event-bus-target-queue"
  delay_seconds              = 0
  max_message_size           = 1024
  message_retention_seconds  = 345600
  visibility_timeout_seconds = 30
  receive_wait_time_seconds  = 10
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.busevents_queue_deadletter.arn
    maxReceiveCount     = 4
  })
}



resource "aws_sqs_queue_policy" "queue" {
  queue_url = aws_sqs_queue.event_bus_target_queue.id
  policy    = data.aws_iam_policy_document.queue_policy.json
}

data "aws_iam_policy_document" "queue_policy" {
  statement {
    actions = ["sqs:*"]
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    resources = [
      aws_sqs_queue.event_bus_target_queue.arn
    ]
  }
}

resource "aws_sqs_queue_policy" "allow_lambda" {
  queue_url = aws_sqs_queue.event_bus_target_queue.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect    = "Allow",
        Principal = "*",
        Action    = "sqs:*",
        Resource  = "${aws_sqs_queue.event_bus_target_queue.arn}",

      }
    ]
  })

}
// DLQ
resource "aws_sqs_queue" "busevents_queue_deadletter" {
  name = "busevents_queue_deadletter"
}

resource "aws_sqs_queue_redrive_allow_policy" "busevents_queue_redrive_allow_policy" {
  queue_url = aws_sqs_queue.busevents_queue_deadletter.id

  redrive_allow_policy = jsonencode({
    redrivePermission = "byQueue",
    sourceQueueArns   = [aws_sqs_queue.event_bus_target_queue.arn]
  })
}
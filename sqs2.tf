resource "aws_sqs_queue" "event_bus_target2_queue" {
  name                       = "event-bus-target2-queue"
  delay_seconds              = 0
  max_message_size           = 1024
  message_retention_seconds  = 345600
  visibility_timeout_seconds = 30
  receive_wait_time_seconds  = 10
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.busevents_queue_deadletter2.arn
    maxReceiveCount     = 4
  })
}



resource "aws_sqs_queue_policy" "queue2" {
  queue_url = aws_sqs_queue.event_bus_target2_queue.id
  policy    = data.aws_iam_policy_document.queue_policy2.json
}

data "aws_iam_policy_document" "queue_policy2" {
  statement {
    actions = ["sqs:*"]
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    resources = [
      aws_sqs_queue.event_bus_target2_queue.arn
    ]
  }
}

resource "aws_sqs_queue_policy" "allow_lambda2" {
  queue_url = aws_sqs_queue.event_bus_target2_queue.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect    = "Allow",
        Principal = "*",
        Action    = "sqs:*",
        Resource  = "${aws_sqs_queue.event_bus_target2_queue.arn}",
      }
    ]
  })

}


// DLQ

resource "aws_sqs_queue" "busevents_queue_deadletter2" {
  name = "busevents_queue_deadletter2"
}

resource "aws_sqs_queue_redrive_allow_policy" "busevents_queue_redrive_allow_policy2" {
  queue_url = aws_sqs_queue.busevents_queue_deadletter2.id

  redrive_allow_policy = jsonencode({
    redrivePermission = "byQueue",
    sourceQueueArns   = [aws_sqs_queue.event_bus_target2_queue.arn]
  })
}
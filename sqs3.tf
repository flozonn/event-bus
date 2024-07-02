resource "aws_sqs_queue" "event_bus_target3_queue" {
  name                       = "event-bus-target3-queue"
  delay_seconds              = 0
  max_message_size           = 1024
  message_retention_seconds  = 345600
  visibility_timeout_seconds = 40
  receive_wait_time_seconds  = 10
  redrive_policy = jsonencode({
    deadLetterTargetArn = "${aws_sqs_queue.busevents_queue_deadletter3.arn}"
    maxReceiveCount     = 4
  })
}






resource "aws_sqs_queue_policy" "queue3" {
  queue_url = aws_sqs_queue.event_bus_target3_queue.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect    = "Allow",
        Principal = "*",
        Action    = "sqs:*",
        Resource  = "${aws_sqs_queue.event_bus_target3_queue.arn}",
      }
    ]
  })

}


resource "aws_sqs_queue_policy" "allow_lambda3" {
  queue_url = aws_sqs_queue.event_bus_target3_queue.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect    = "Allow",
        Principal = "*",
        Action    = "sqs:*",
        Resource  = "${aws_sqs_queue.event_bus_target3_queue.arn}",
      }
    ]
  })

}


// DLQ

resource "aws_sqs_queue" "busevents_queue_deadletter3" {
  name = "busevents_queue_deadletter3"
}

resource "aws_sqs_queue_redrive_allow_policy" "busevents_queue_redrive_allow_policy3" {
  queue_url = aws_sqs_queue.busevents_queue_deadletter3.id

  redrive_allow_policy = jsonencode({
    redrivePermission = "byQueue",
    sourceQueueArns   = ["${aws_sqs_queue.event_bus_target3_queue.arn}"]
  })
}
# Create the event bus
resource "aws_cloudwatch_event_bus" "event_bus" {
  name = "olf-event_bus"
}

resource "aws_cloudwatch_event_bus_policy" "olf_event_bus_policy" {
  event_bus_name = aws_cloudwatch_event_bus.event_bus.name
  policy         = data.aws_iam_policy_document.event_bus.json
}

data "aws_iam_policy_document" "event_bus" {
  statement {
    sid    = "AllowCurrentAccountToPutEvents"
    effect = "Allow"
    principals {
      type = "AWS"
      identifiers = [
        "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
      ]
    }
    actions = [
      "events:PutEvents"
    ]
    resources = [
      "*"
    ]
  }
}

// Adding a rule to direct events to SQS

resource "aws_cloudwatch_event_rule" "events_go_queue" {
  name           = "events-go-queue"
  description    = "Redirect events from the bus to a consumer's queue"
  event_bus_name = aws_cloudwatch_event_bus.event_bus.name
  event_pattern = jsonencode({
    source = [
      "overwhelm.go"
    ]
  })
}

resource "aws_cloudwatch_event_rule" "events_go_queue2" {
  name           = "events-go-queue2"
  description    = "Redirect events from the bus to a consumer's queue"
  event_bus_name = aws_cloudwatch_event_bus.event_bus.name
  event_pattern = jsonencode({
    source = [
      "overwhelm.go"
    ]
  })
}

resource "aws_cloudwatch_event_rule" "events_go_queue3" {
  name           = "events-go-queue3"
  description    = "Redirect events from the bus to a consumer's queue"
  event_bus_name = aws_cloudwatch_event_bus.event_bus.name
  event_pattern = jsonencode({
    source = [
      "overwhelm.go"
    ]
  })
}



// define a target for the rule
resource "aws_cloudwatch_event_target" "sqs_events_target" {
  rule           = aws_cloudwatch_event_rule.events_go_queue.name
  target_id      = "event_bus_target"
  event_bus_name = aws_cloudwatch_event_bus.event_bus.name

  arn = aws_sqs_queue.event_bus_target_queue.arn

}

resource "aws_cloudwatch_event_target" "sqs_events_target2" {
  rule           = aws_cloudwatch_event_rule.events_go_queue2.name
  target_id      = "event_bus_target2"
  event_bus_name = aws_cloudwatch_event_bus.event_bus.name

  arn = aws_sqs_queue.event_bus_target2_queue.arn

}

resource "aws_cloudwatch_event_target" "sqs_events_target3" {
  rule           = aws_cloudwatch_event_rule.events_go_queue3.name
  target_id      = "event_bus_target3"
  event_bus_name = aws_cloudwatch_event_bus.event_bus.name

  arn = aws_sqs_queue.event_bus_target3_queue.arn

}
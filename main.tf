

resource "aws_cloudwatch_event_rule" "this" {
  name        = "capture-new-record-on-route-53"
  description = "Capture every new record added on route 53"

  event_pattern = <<EOF
{
  "detail-type": [
    "AWS Console Sign In via CloudTrail"
  ]
}
EOF
}

resource "aws_cloudwatch_event_target" "sns" {
  rule      = aws_cloudwatch_event_rule.this.name
  target_id = "SendToSNS"
  arn       = aws_sns_topic.aws_logins.arn
}

resource "aws_sns_topic" "aws_logins" {
  name = "aws-console-logins"
}

resource "aws_sns_topic_policy" "default" {
  arn    = aws_sns_topic.aws_logins.arn
  policy = data.aws_iam_policy_document.sns_topic_policy.json
}

data "aws_iam_policy_document" "sns_topic_policy" {
  statement {
    effect  = "Allow"
    actions = ["SNS:Publish"]

    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }

    resources = [aws_sns_topic.aws_logins.arn]
  }
}




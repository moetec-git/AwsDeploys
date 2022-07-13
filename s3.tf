
# creating an aws_s3_bucket
resource "aws_s3_bucket" "bucket-1" {
  bucket        =  "teebuckjay32"
  force_destroy = true
}

resource "aws_s3_bucket_acl" "example_bucket_acl" {
  bucket = aws_s3_bucket.bucket-1.id
  acl    = "private"
}

#creating a cloud trail 
data "aws_caller_identity" "current" {}

resource "aws_cloudtrail" "test" {
  name                          = "tf-trail-test"
  s3_bucket_name                = aws_s3_bucket.bucket-1.id
  s3_key_prefix                 = "prefix"
  include_global_service_events = false
}

resource "aws_s3_bucket_policy" "foo" {
  bucket = aws_s3_bucket.bucket-1.id
  policy = <<POLICY
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "AWSCloudTrailAclCheck",
            "Effect": "Allow",
            "Principal": {
              "Service": "cloudtrail.amazonaws.com"
            },
            "Action": "s3:GetBucketAcl",
            "Resource": "${aws_s3_bucket.bucket-1.arn}"
        },
        {
            "Sid": "AWSCloudTrailWrite",
            "Effect": "Allow",
            "Principal": {
              "Service": "cloudtrail.amazonaws.com"
            },
            "Action": "s3:PutObject",
            "Resource": "${aws_s3_bucket.bucket-1.arn}/prefix/AWSLogs/${data.aws_caller_identity.current.account_id}/*",
            "Condition": {
                "StringEquals": {
                    "s3:x-amz-acl": "bucket-owner-full-control"
                }
            }
        }
    ]
}
POLICY
}


## aws_iam_role

resource "aws_iam_role" "lambda-role" {
  name = "Route-53-backup"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": "AllowPublicHostedZonePermissions"
    }
  ]
}
EOF
}

## aws_iam_role_policy

resource "aws_iam_policy" "lambda-policy" {
  name = "route-53-backup"
  description = "policy to grant permissions to the actions that are required to create and manage public hosted zones and their records"

 policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid" : "AllowPublicHostedZonePermissions",
            "Effect": "Allow",
            "Action": [
                "route53:CreateHostedZone",
                "route53:UpdateHostedZoneComment",
                "route53:GetHostedZone",
                "route53:ListHostedZones",
                "route53:DeleteHostedZone",
                "route53:ChangeResourceRecordSets",
                "route53:ListResourceRecordSets",
                "route53:GetHostedZoneCount",
                "route53:ListHostedZonesByName"
            ],
            "Resource": "*"
        },
        {
         "Sid" : "AllowHealthCheckPermissions",
            "Effect": "Allow",
            "Action": [
                "route53:CreateHealthCheck",
                "route53:UpdateHealthCheck",
                "route53:GetHealthCheck",
                "route53:ListHealthChecks",
                "route53:DeleteHealthCheck",
                "route53:GetCheckerIpRanges",
                "route53:GetHealthCheckCount",
                "route53:GetHealthCheckStatus",
                "route53:GetHealthCheckLastFailureReason"
            ],
            "Resource": "*"
        }
      ]
 })
}


resource "aws_iam_role_policy_attachment" "test-" {
  role       = aws_iam_role.lambda-role.name
  policy_arn = aws_iam_policy.lambda-policy.arn
}

resource "aws_lambda_function" "route-53-backup" {
  # If the file is not in the current working directory you will need to include a 
  # path.module in the filename.
  filename      = "aws_s3_route53-try.zip"
  function_name = "lambda"
  role          = aws_iam_role.lambda-role.arn
  handler       = "lambda.lambda_handler"

  # The filebase64sha256() function is available in Terraform 0.11.12 and later
  # For Terraform 0.11.11 and earlier, use the base64sha256() function and the file() function:
  # source_code_hash = "${base64sha256(file("lambda_function_payload.zip"))}"
  source_code_hash = filebase64sha256("aws_s3_route53-try.zip")

  runtime = "python3.7"
  timeout = 63
}

resource "aws_cloudwatch_event_rule" "route53-backup" {
  name        = "backup-record-on-route-53"
  description = "backup every record added on route 53 every 1 hours"
  schedule_expression = "rate(60 minutes)"
}

resource "aws_cloudwatch_event_target" "route53-backup" {
  rule      = aws_cloudwatch_event_rule.route53-backup.name
  target_id = "lambda"
  arn       = aws_lambda_function.route-53-backup.arn
}

resource "aws_lambda_permission" "allow_cloudwatch" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.route-53-backup.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.route53-backup.arn
}


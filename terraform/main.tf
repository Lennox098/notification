terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.0"
    }
  }

  required_version = ">= 1.3.0"
}

provider "aws" {
  region = var.aws_region
}

# --- S3 para plantillas ---
resource "aws_s3_bucket" "templates" {
  bucket = var.s3_bucket_name
}

# --- DynamoDB ---
resource "aws_dynamodb_table" "notification" {
  name         = var.notification_table
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "uuid"
  range_key    = "createdAt"

  attribute {
    name = "uuid"
    type = "S"
  }

  attribute {
    name = "createdAt"
    type = "S"
  }
}

resource "aws_dynamodb_table" "notification_error" {
  name         = var.notification_error_table
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "uuid"
  range_key    = "createdAt"

  attribute {
    name = "uuid"
    type = "S"
  }

  attribute {
    name = "createdAt"
    type = "S"
  }
}

# --- SQS ---
resource "aws_sqs_queue" "notification_dlq" {
  name = var.notification_dlq_name
}

resource "aws_sqs_queue" "notification_email" {
  name = var.notification_queue_name

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.notification_dlq.arn
    maxReceiveCount     = 3
  })
}

# --- Roles IAM ---
resource "aws_iam_role" "lambda_role" {
  name = "notification-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action    = "sts:AssumeRole",
      Effect    = "Allow",
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_policy_attach" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "sqs_policy_attach" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSQSFullAccess"
}

resource "aws_iam_role_policy_attachment" "s3_policy_attach" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

resource "aws_iam_role_policy_attachment" "dynamo_policy_attach" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess"
}

resource "aws_iam_role_policy_attachment" "ses_policy_attach" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSESFullAccess"
}

# --- Lambda principal ---
resource "aws_lambda_function" "send_notifications" {
  function_name = "send-notifications-lambda"
  role          = aws_iam_role.lambda_role.arn
  runtime       = "nodejs18.x"
  handler       = "index.handler"

  filename         = "${path.module}/send-notifications.zip"
  source_code_hash = filebase64sha256("${path.module}/send-notifications.zip")

  environment {
    variables = {
      S3_BUCKET_NAME = var.s3_bucket_name
      DYNAMO_TABLE   = var.notification_table
      EMAIL_SOURCE   = var.email_source
    }
  }
}

# --- Lambda de errores ---
resource "aws_lambda_function" "send_notifications_error" {
  function_name = "send-notifications-error-lambda"
  role          = aws_iam_role.lambda_role.arn
  runtime       = "nodejs18.x"
  handler       = "index.handler"

  filename         = "${path.module}/send-notifications-error.zip"
  source_code_hash = filebase64sha256("${path.module}/send-notifications-error.zip")

  environment {
    variables = {
      DYNAMO_ERROR_TABLE = var.notification_error_table
    }
  }
}

# --- Trigger SQS -> Lambda ---
resource "aws_lambda_event_source_mapping" "sqs_trigger" {
  event_source_arn = aws_sqs_queue.notification_email.arn
  function_name    = aws_lambda_function.send_notifications.arn
  batch_size       = 5
  enabled          = true
}

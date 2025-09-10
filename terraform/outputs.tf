output "sqs_queue_url" {
  value = aws_sqs_queue.notification_email.id
}

output "s3_bucket_name" {
  value = aws_s3_bucket.templates.bucket
}

output "notification_table" {
  value = aws_dynamodb_table.notification.name
}

output "notification_error_table" {
  value = aws_dynamodb_table.notification_error.name
}

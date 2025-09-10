variable "aws_region" {
  description = "Región AWS donde se desplegarán los recursos"
  type        = string
  default     = "us-east-1"
}

variable "s3_bucket_name" {
  description = "Nombre único para el bucket de plantillas"
  type        = string
}

variable "email_source" {
  description = "Correo verificado en SES como remitente"
  type        = string
}

variable "notification_table" {
  description = "Tabla DynamoDB para notificaciones exitosas"
  type        = string
  default     = "notification-table"
}

variable "notification_error_table" {
  description = "Tabla DynamoDB para notificaciones fallidas"
  type        = string
  default     = "notification-error-table"
}

variable "notification_queue_name" {
  description = "Nombre de la cola SQS principal"
  type        = string
  default     = "notification-email-sqs"
}

variable "notification_dlq_name" {
  description = "Nombre de la cola DLQ"
  type        = string
  default     = "notification-email-error-sqs"
}

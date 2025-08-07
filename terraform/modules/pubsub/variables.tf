# Basic Configuration
variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "region" {
  description = "The GCP region"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "labels" {
  description = "Common labels to apply to resources"
  type        = map(string)
  default     = {}
}

# Pub/Sub Configuration
variable "topic_prefix" {
  description = "Prefix for Pub/Sub topic names"
  type        = string
  default     = "formio"
}

variable "message_retention_duration" {
  description = "Message retention duration for topics"
  type        = string
  default     = "86400s" # 24 hours
}

variable "subscription_message_retention_duration" {
  description = "Message retention duration for subscriptions"
  type        = string
  default     = "604800s" # 7 days
}

variable "ack_deadline_seconds" {
  description = "Acknowledgment deadline for subscriptions in seconds"
  type        = number
  default     = 20
}

variable "max_delivery_attempts" {
  description = "Maximum delivery attempts before sending to dead letter topic"
  type        = number
  default     = 5
}

variable "enable_message_ordering" {
  description = "Enable message ordering for subscriptions"
  type        = bool
  default     = false
}

variable "enable_schema_validation" {
  description = "Enable schema validation for form events"
  type        = bool
  default     = false
}

# Service Endpoints for Push Subscriptions
variable "webhook_processor_endpoint" {
  description = "Endpoint URL for webhook processor service"
  type        = string
  default     = ""
}

variable "api_layer_endpoint" {
  description = "Endpoint URL for API layer service"
  type        = string
  default     = ""
}

variable "form_orchestrator_endpoint" {
  description = "Endpoint URL for form orchestrator service"
  type        = string
  default     = ""
}

variable "data_prefill_endpoint" {
  description = "Endpoint URL for data prefill service"
  type        = string
  default     = ""
}

# Service Accounts for OIDC Authentication
variable "webhook_processor_service_account" {
  description = "Service account email for webhook processor"
  type        = string
  default     = ""
}

variable "api_layer_service_account" {
  description = "Service account email for API layer"
  type        = string
  default     = ""
}

variable "form_orchestrator_service_account" {
  description = "Service account email for form orchestrator"
  type        = string
  default     = ""
}

variable "data_prefill_service_account" {
  description = "Service account email for data prefill service"
  type        = string
  default     = ""
}

variable "formio_service_account" {
  description = "Service account email for Form.io service"
  type        = string
  default     = ""
}

variable "monitoring_service_account" {
  description = "Service account email for monitoring service"
  type        = string
  default     = ""
}
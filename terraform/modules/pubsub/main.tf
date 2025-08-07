terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }
}

# Pub/Sub Topics for Form.io Events
resource "google_pubsub_topic" "form_events" {
  name = "${var.topic_prefix}-form-events-${var.environment}"
  
  labels = var.labels
  
  message_retention_duration = var.message_retention_duration
  
  dynamic "schema_settings" {
    for_each = var.enable_schema_validation ? [1] : []
    content {
      schema   = google_pubsub_schema.form_event_schema[0].id
      encoding = "JSON"
    }
  }
}

resource "google_pubsub_topic" "form_submissions" {
  name = "${var.topic_prefix}-form-submissions-${var.environment}"
  
  labels = var.labels
  
  message_retention_duration = var.message_retention_duration
}

resource "google_pubsub_topic" "form_updates" {
  name = "${var.topic_prefix}-form-updates-${var.environment}"
  
  labels = var.labels
  
  message_retention_duration = var.message_retention_duration
}

resource "google_pubsub_topic" "data_prefill_requests" {
  name = "${var.topic_prefix}-data-prefill-${var.environment}"
  
  labels = var.labels
  
  message_retention_duration = var.message_retention_duration
}

resource "google_pubsub_topic" "webhook_events" {
  name = "${var.topic_prefix}-webhook-events-${var.environment}"
  
  labels = var.labels
  
  message_retention_duration = var.message_retention_duration
}

# Dead Letter Topics for failed message processing
resource "google_pubsub_topic" "dead_letter" {
  name = "${var.topic_prefix}-dead-letter-${var.environment}"
  
  labels = merge(var.labels, {
    purpose = "dead-letter"
  })
  
  message_retention_duration = "604800s" # 7 days
}

# Schema for form event messages (optional)
resource "google_pubsub_schema" "form_event_schema" {
  count = var.enable_schema_validation ? 1 : 0
  
  name = "${var.topic_prefix}-form-event-schema-${var.environment}"
  type = "AVRO"
  
  definition = jsonencode({
    type = "record"
    name = "FormEvent"
    fields = [
      {
        name = "eventId"
        type = "string"
      },
      {
        name = "eventType"
        type = {
          type = "enum"
          name = "EventType"
          symbols = [
            "FORM_CREATED",
            "FORM_UPDATED", 
            "FORM_DELETED",
            "SUBMISSION_CREATED",
            "SUBMISSION_UPDATED",
            "SUBMISSION_DELETED",
            "USER_ACTION"
          ]
        }
      },
      {
        name = "timestamp"
        type = "long"
        logicalType = "timestamp-millis"
      },
      {
        name = "formId"
        type = ["null", "string"]
        default = null
      },
      {
        name = "submissionId"
        type = ["null", "string"]
        default = null
      },
      {
        name = "userId"
        type = ["null", "string"]
        default = null
      },
      {
        name = "data"
        type = {
          type = "map"
          values = "string"
        }
      }
    ]
  })
}

# Subscriptions for different services
resource "google_pubsub_subscription" "webhook_processor_sub" {
  name  = "${var.topic_prefix}-webhook-processor-${var.environment}"
  topic = google_pubsub_topic.form_events.name
  
  labels = var.labels
  
  message_retention_duration = var.subscription_message_retention_duration
  retain_acked_messages      = false
  ack_deadline_seconds       = var.ack_deadline_seconds
  
  push_config {
    push_endpoint = var.webhook_processor_endpoint
    
    attributes = {
      x-goog-version = "v1"
    }
    
    dynamic "oidc_token" {
      for_each = var.webhook_processor_service_account != "" ? [1] : []
      content {
        service_account_email = var.webhook_processor_service_account
      }
    }
  }
  
  dead_letter_policy {
    dead_letter_topic     = google_pubsub_topic.dead_letter.id
    max_delivery_attempts = var.max_delivery_attempts
  }
  
  retry_policy {
    minimum_backoff = "10s"
    maximum_backoff = "600s"
  }
  
  enable_message_ordering = var.enable_message_ordering
}

resource "google_pubsub_subscription" "api_layer_sub" {
  name  = "${var.topic_prefix}-api-layer-${var.environment}"
  topic = google_pubsub_topic.form_submissions.name
  
  labels = var.labels
  
  message_retention_duration = var.subscription_message_retention_duration
  retain_acked_messages      = false
  ack_deadline_seconds       = var.ack_deadline_seconds
  
  push_config {
    push_endpoint = var.api_layer_endpoint
    
    attributes = {
      x-goog-version = "v1"
    }
    
    dynamic "oidc_token" {
      for_each = var.api_layer_service_account != "" ? [1] : []
      content {
        service_account_email = var.api_layer_service_account
      }
    }
  }
  
  dead_letter_policy {
    dead_letter_topic     = google_pubsub_topic.dead_letter.id
    max_delivery_attempts = var.max_delivery_attempts
  }
  
  retry_policy {
    minimum_backoff = "10s"
    maximum_backoff = "600s"
  }
}

resource "google_pubsub_subscription" "form_orchestrator_sub" {
  name  = "${var.topic_prefix}-form-orchestrator-${var.environment}"
  topic = google_pubsub_topic.form_updates.name
  
  labels = var.labels
  
  message_retention_duration = var.subscription_message_retention_duration
  retain_acked_messages      = false
  ack_deadline_seconds       = var.ack_deadline_seconds
  
  push_config {
    push_endpoint = var.form_orchestrator_endpoint
    
    attributes = {
      x-goog-version = "v1"
    }
    
    dynamic "oidc_token" {
      for_each = var.form_orchestrator_service_account != "" ? [1] : []
      content {
        service_account_email = var.form_orchestrator_service_account
      }
    }
  }
  
  dead_letter_policy {
    dead_letter_topic     = google_pubsub_topic.dead_letter.id
    max_delivery_attempts = var.max_delivery_attempts
  }
  
  retry_policy {
    minimum_backoff = "10s"
    maximum_backoff = "600s"
  }
}

resource "google_pubsub_subscription" "data_prefill_sub" {
  name  = "${var.topic_prefix}-data-prefill-${var.environment}"
  topic = google_pubsub_topic.data_prefill_requests.name
  
  labels = var.labels
  
  message_retention_duration = var.subscription_message_retention_duration
  retain_acked_messages      = false
  ack_deadline_seconds       = var.ack_deadline_seconds
  
  push_config {
    push_endpoint = var.data_prefill_endpoint
    
    attributes = {
      x-goog-version = "v1"
    }
    
    dynamic "oidc_token" {
      for_each = var.data_prefill_service_account != "" ? [1] : []
      content {
        service_account_email = var.data_prefill_service_account
      }
    }
  }
  
  dead_letter_policy {
    dead_letter_topic     = google_pubsub_topic.dead_letter.id
    max_delivery_attempts = var.max_delivery_attempts
  }
  
  retry_policy {
    minimum_backoff = "10s"
    maximum_backoff = "600s"
  }
}

# Dead letter subscription for monitoring failed messages
resource "google_pubsub_subscription" "dead_letter_sub" {
  name  = "${var.topic_prefix}-dead-letter-monitor-${var.environment}"
  topic = google_pubsub_topic.dead_letter.name
  
  labels = merge(var.labels, {
    purpose = "monitoring"
  })
  
  message_retention_duration = "604800s" # 7 days
  retain_acked_messages      = false
  ack_deadline_seconds       = 600 # 10 minutes for manual inspection
  
  # Pull subscription for manual inspection/alerting
}

# IAM bindings for Pub/Sub publisher role
resource "google_pubsub_topic_iam_member" "formio_publisher" {
  count = var.formio_service_account != "" ? 1 : 0
  
  topic  = google_pubsub_topic.form_events.name
  role   = "roles/pubsub.publisher"
  member = "serviceAccount:${var.formio_service_account}"
}

resource "google_pubsub_topic_iam_member" "webhook_publisher" {
  count = var.webhook_processor_service_account != "" ? 1 : 0
  
  topic  = google_pubsub_topic.webhook_events.name
  role   = "roles/pubsub.publisher"
  member = "serviceAccount:${var.webhook_processor_service_account}"
}

# IAM bindings for Pub/Sub subscriber role
resource "google_pubsub_subscription_iam_member" "dead_letter_monitor" {
  count = var.monitoring_service_account != "" ? 1 : 0
  
  subscription = google_pubsub_subscription.dead_letter_sub.name
  role         = "roles/pubsub.subscriber"
  member       = "serviceAccount:${var.monitoring_service_account}"
}
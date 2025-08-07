output "topic_names" {
  description = "Names of created Pub/Sub topics"
  value = {
    form_events          = google_pubsub_topic.form_events.name
    form_submissions     = google_pubsub_topic.form_submissions.name
    form_updates         = google_pubsub_topic.form_updates.name
    data_prefill_requests = google_pubsub_topic.data_prefill_requests.name
    webhook_events       = google_pubsub_topic.webhook_events.name
    dead_letter          = google_pubsub_topic.dead_letter.name
  }
}

output "topic_ids" {
  description = "IDs of created Pub/Sub topics"
  value = {
    form_events          = google_pubsub_topic.form_events.id
    form_submissions     = google_pubsub_topic.form_submissions.id
    form_updates         = google_pubsub_topic.form_updates.id
    data_prefill_requests = google_pubsub_topic.data_prefill_requests.id
    webhook_events       = google_pubsub_topic.webhook_events.id
    dead_letter          = google_pubsub_topic.dead_letter.id
  }
}

output "subscription_names" {
  description = "Names of created Pub/Sub subscriptions"
  value = {
    webhook_processor  = google_pubsub_subscription.webhook_processor_sub.name
    api_layer         = google_pubsub_subscription.api_layer_sub.name
    form_orchestrator = google_pubsub_subscription.form_orchestrator_sub.name
    data_prefill      = google_pubsub_subscription.data_prefill_sub.name
    dead_letter       = google_pubsub_subscription.dead_letter_sub.name
  }
}

output "subscription_ids" {
  description = "IDs of created Pub/Sub subscriptions"
  value = {
    webhook_processor  = google_pubsub_subscription.webhook_processor_sub.id
    api_layer         = google_pubsub_subscription.api_layer_sub.id
    form_orchestrator = google_pubsub_subscription.form_orchestrator_sub.id
    data_prefill      = google_pubsub_subscription.data_prefill_sub.id
    dead_letter       = google_pubsub_subscription.dead_letter_sub.id
  }
}

output "schema_id" {
  description = "ID of the form event schema (if enabled)"
  value       = var.enable_schema_validation ? google_pubsub_schema.form_event_schema[0].id : null
}

# Topic URLs for publishing
output "topic_urls" {
  description = "Full URLs for publishing to topics"
  value = {
    form_events          = "projects/${var.project_id}/topics/${google_pubsub_topic.form_events.name}"
    form_submissions     = "projects/${var.project_id}/topics/${google_pubsub_topic.form_submissions.name}"
    form_updates         = "projects/${var.project_id}/topics/${google_pubsub_topic.form_updates.name}"
    data_prefill_requests = "projects/${var.project_id}/topics/${google_pubsub_topic.data_prefill_requests.name}"
    webhook_events       = "projects/${var.project_id}/topics/${google_pubsub_topic.webhook_events.name}"
    dead_letter          = "projects/${var.project_id}/topics/${google_pubsub_topic.dead_letter.name}"
  }
}

# Subscription URLs for pulling
output "subscription_urls" {
  description = "Full URLs for subscription operations"
  value = {
    webhook_processor  = "projects/${var.project_id}/subscriptions/${google_pubsub_subscription.webhook_processor_sub.name}"
    api_layer         = "projects/${var.project_id}/subscriptions/${google_pubsub_subscription.api_layer_sub.name}"
    form_orchestrator = "projects/${var.project_id}/subscriptions/${google_pubsub_subscription.form_orchestrator_sub.name}"
    data_prefill      = "projects/${var.project_id}/subscriptions/${google_pubsub_subscription.data_prefill_sub.name}"
    dead_letter       = "projects/${var.project_id}/subscriptions/${google_pubsub_subscription.dead_letter_sub.name}"
  }
}
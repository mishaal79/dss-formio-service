# Custom Domain Mappings for Form.io Whitelabeling
# These domain mappings will be activated once DNS is configured in the org project

# Domain mappings for custom domains (whitelabeling)
resource "google_cloud_run_domain_mapping" "custom_domains" {
  for_each = toset(var.custom_domains)

  location = var.region
  name     = each.value

  spec {
    route_name = google_cloud_run_v2_service.formio_service.name
  }

  metadata {
    namespace = var.project_id
    labels    = local.service_labels
    annotations = {
      "run.googleapis.com/launch-stage" = "BETA"
    }
  }

  # Domain mappings depend on the service being deployed
  depends_on = [google_cloud_run_v2_service.formio_service]
}

# Output domain mapping status for monitoring
output "domain_mappings" {
  description = "Status of custom domain mappings"
  value = {
    for domain, mapping in google_cloud_run_domain_mapping.custom_domains : domain => {
      name   = mapping.name
      status = mapping.status
    }
  }
}
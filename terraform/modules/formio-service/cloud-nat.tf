# =============================================================================
# TODO: CLOUD NAT GATEWAY IMPLEMENTATION REQUIRED
# =============================================================================
#
# CRITICAL: Current egress = "PRIVATE_RANGES_ONLY" blocks internet access
# 
# Form.io services REQUIRE internet connectivity for:
# 1. MongoDB Atlas connection (mongodb+srv://*.mongodb.net)
# 2. Form.io Enterprise license validation (license servers)
# 3. Third-party API integrations (payment, email, webhooks)
# 4. Google APIs via public endpoints
#
# WITHOUT Cloud NAT, the service will experience:
# - Database connection failures
# - License validation errors  
# - Integration failures
# - Startup timeouts
#
# =============================================================================
# IMPLEMENTATION NOTES:
# =============================================================================
#
# Cloud NAT should provide:
# - Controlled outbound internet access
# - Static IP allocation for whitelisting
# - Traffic logging for security monitoring
# - Cost-optimized port allocation
#
# Architecture decision:
# - Option A: Implement in central infrastructure repo (recommended)
# - Option B: Implement in this module (service-specific)
#
# =============================================================================

# Placeholder for Cloud NAT implementation
# Uncomment and configure when ready to implement:

/*
resource "google_compute_router" "formio_router" {
  name    = "${var.service_name}-router-${var.environment}"
  region  = var.region
  network = "projects/erlich-dev/global/networks/erlich-vpc-dev"
  project = var.project_id
}

resource "google_compute_router_nat" "formio_nat" {
  name   = "${var.service_name}-nat-${var.environment}"
  router = google_compute_router.formio_router.name
  region = var.region
  project = var.project_id

  nat_ip_allocate_option = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"
  
  subnetwork {
    name = "projects/erlich-dev/regions/${var.region}/subnetworks/erlich-vpc-egress-subnet-dev"
    source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
  }

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}
*/
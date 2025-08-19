# Load Balancer Module with Cloud Armor Security
# Provides DDoS protection, bot detection, and security for Form.io Enterprise

locals {
  # Standard labels
  common_labels = merge(var.labels, {
    service   = "load-balancer"
    component = "security"
    tier      = var.environment
  })
}

# =============================================================================
# CLOUD ARMOR SECURITY POLICY
# =============================================================================

# Cloud Armor security policy for DDoS protection and bot detection
resource "google_compute_security_policy" "formio_security_policy" {
  name        = "${var.service_name}-security-policy-${var.environment}"
  description = "Cloud Armor security policy for Form.io Enterprise with bot detection and DDoS protection"
  project     = var.project_id

  # Default rule - allow all (will be refined with specific rules)
  rule {
    action   = "allow"
    priority = "2147483647"
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }
    description = "Default allow rule"
  }

  # Rate limiting rule - prevent abuse (lower priority - evaluated after bot blocking)
  rule {
    action   = "rate_based_ban"
    priority = "1000"
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }
    description = "Rate limiting rule - ban IPs with excessive requests"
    rate_limit_options {
      conform_action = "allow"
      exceed_action  = "deny(429)"
      enforce_on_key = "IP"
      rate_limit_threshold {
        count        = var.rate_limit_threshold_count
        interval_sec = var.rate_limit_threshold_interval
      }
      ban_duration_sec = var.rate_limit_ban_duration
    }
  }


  # Geographic blocking - Australia only (highest priority after health checks)
  dynamic "rule" {
    for_each = var.enable_geo_blocking ? [1] : []
    content {
      action   = "deny(403)"
      priority = "100"
      match {
        expr {
          expression = "origin.region_code != 'AU'"
        }
      }
      description = "Allow traffic only from Australia (blocks all other countries)"
    }
  }

  # OWASP Top 10 protection - comprehensive web application security (SECURITY FIX)  
  rule {
    action   = "deny(403)"
    priority = "200"
    match {
      expr {
        expression = "evaluatePreconfiguredWaf('sqli-v33-stable') || evaluatePreconfiguredWaf('xss-v33-stable')"
      }
    }
    description = "OWASP Top 10 comprehensive protection - SQLi and XSS detection"
  }

  # Advanced bot management - replace basic user-agent blocking
  rule {
    action   = "deny(403)"
    priority = "300"
    match {
      expr {
        expression = "request.headers['user-agent'].contains('bot') || request.headers['user-agent'].contains('crawler') || request.headers['user-agent'].contains('spider')"
      }
    }
    description = "Basic bot detection and blocking"
  }

  # Allow health checks from Google
  rule {
    action   = "allow"
    priority = "500"
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = [
          "35.191.0.0/16", # Google health check ranges
          "130.211.0.0/22",
          "209.85.152.0/22",
          "209.85.204.0/22"
        ]
      }
    }
    description = "Allow Google health checks"
  }


  # Adaptive protection (Google's ML-based bot detection)
  adaptive_protection_config {
    layer_7_ddos_defense_config {
      enable          = true
      rule_visibility = "STANDARD"
    }
  }
}

# =============================================================================
# GLOBAL STATIC IP ADDRESS
# =============================================================================

# Reserved global static IP for the load balancer
resource "google_compute_global_address" "formio_lb_ip" {
  name         = "${var.service_name}-lb-ip-${var.environment}"
  description  = "Static IP for Form.io Enterprise load balancer"
  project      = var.project_id
  ip_version   = "IPV4"
  address_type = "EXTERNAL"
}

# =============================================================================
# CLOUD RUN BACKEND SERVICE
# =============================================================================

# Backend service pointing to Cloud Run
resource "google_compute_backend_service" "formio_backend" {
  name                  = "${var.service_name}-backend-${var.environment}"
  description           = "Backend service for Form.io Enterprise Cloud Run"
  project               = var.project_id
  protocol              = "HTTP"
  port_name             = "http"
  load_balancing_scheme = "EXTERNAL"
  timeout_sec           = 30
  enable_cdn            = false
  security_policy       = google_compute_security_policy.formio_security_policy.id
  
  # Session affinity for Form.io stateful operations
  session_affinity                = "CLIENT_IP"
  affinity_cookie_ttl_sec        = 3600  # 1 hour

  backend {
    group = google_compute_region_network_endpoint_group.formio_neg.id
  }

  # Note: Health checks are not supported for serverless NEGs (Cloud Run)
  # Cloud Run handles health checks internally

  log_config {
    enable      = true
    sample_rate = 1.0
  }

  iap {
    enabled = false
  }
}

# =============================================================================
# NETWORK ENDPOINT GROUP
# =============================================================================

# Network Endpoint Group for Cloud Run service
resource "google_compute_region_network_endpoint_group" "formio_neg" {
  name                  = "${var.service_name}-neg-${var.environment}"
  description           = "Network endpoint group for Form.io Enterprise Cloud Run"
  project               = var.project_id
  region                = var.region
  network_endpoint_type = "SERVERLESS"

  cloud_run {
    service = var.cloud_run_service_name
  }
}

# =============================================================================
# HEALTH CHECK
# =============================================================================

# Health check for the backend service
resource "google_compute_health_check" "formio_health_check" {
  name                = "${var.service_name}-health-check-${var.environment}"
  description         = "Health check for Form.io Enterprise"
  project             = var.project_id
  timeout_sec         = 10
  check_interval_sec  = 30
  healthy_threshold   = 2
  unhealthy_threshold = 3

  http_health_check {
    port         = 80
    request_path = "/health"
  }

  log_config {
    enable = true
  }
}

# =============================================================================
# URL MAP
# =============================================================================

# URL map to route traffic to the backend service
resource "google_compute_url_map" "formio_url_map" {
  name            = "${var.service_name}-url-map-${var.environment}"
  description     = "URL map for Form.io Enterprise load balancer"
  project         = var.project_id
  default_service = google_compute_backend_service.formio_backend.id

  # Optional: Add path-based routing rules here if needed
  # host_rule {
  #   hosts        = [var.custom_domain]
  #   path_matcher = "allpaths"
  # }
  #
  # path_matcher {
  #   name            = "allpaths"
  #   default_service = google_compute_backend_service.formio_backend.id
  # }
}

# =============================================================================
# SSL CERTIFICATE
# =============================================================================

# Managed SSL certificate for HTTPS
resource "google_compute_managed_ssl_certificate" "formio_ssl_cert" {
  name        = "${var.service_name}-ssl-cert-${var.environment}"
  description = "Managed SSL certificate for Form.io Enterprise"
  project     = var.project_id

  managed {
    domains = var.ssl_domains
  }

  lifecycle {
    create_before_destroy = true
  }
}

# =============================================================================
# HTTPS PROXY
# =============================================================================

# HTTPS target proxy
resource "google_compute_target_https_proxy" "formio_https_proxy" {
  name             = "${var.service_name}-https-proxy-${var.environment}"
  description      = "HTTPS proxy for Form.io Enterprise"
  project          = var.project_id
  url_map          = google_compute_url_map.formio_url_map.id
  ssl_certificates = [google_compute_managed_ssl_certificate.formio_ssl_cert.id]

  # Enable QUIC for improved performance
  quic_override = "ENABLE"
}

# =============================================================================
# GLOBAL FORWARDING RULE
# =============================================================================

# Global forwarding rule for HTTPS traffic
resource "google_compute_global_forwarding_rule" "formio_https_forwarding_rule" {
  name                  = "${var.service_name}-https-forwarding-rule-${var.environment}"
  description           = "HTTPS forwarding rule for Form.io Enterprise"
  project               = var.project_id
  ip_protocol           = "TCP"
  load_balancing_scheme = "EXTERNAL"
  port_range            = "443"
  target                = google_compute_target_https_proxy.formio_https_proxy.id
  ip_address            = google_compute_global_address.formio_lb_ip.id
}

# Global forwarding rule for HTTP traffic (redirect to HTTPS)
resource "google_compute_global_forwarding_rule" "formio_http_forwarding_rule" {
  name                  = "${var.service_name}-http-forwarding-rule-${var.environment}"
  description           = "HTTP forwarding rule for Form.io Enterprise (redirects to HTTPS)"
  project               = var.project_id
  ip_protocol           = "TCP"
  load_balancing_scheme = "EXTERNAL"
  port_range            = "80"
  target                = google_compute_target_http_proxy.formio_http_proxy.id
  ip_address            = google_compute_global_address.formio_lb_ip.id
}

# HTTP target proxy for HTTP to HTTPS redirect
resource "google_compute_target_http_proxy" "formio_http_proxy" {
  name        = "${var.service_name}-http-proxy-${var.environment}"
  description = "HTTP proxy for Form.io Enterprise (redirects to HTTPS)"
  project     = var.project_id
  url_map     = google_compute_url_map.formio_http_redirect.id
}

# URL map for HTTP to HTTPS redirect
resource "google_compute_url_map" "formio_http_redirect" {
  name        = "${var.service_name}-http-redirect-${var.environment}"
  description = "URL map for HTTP to HTTPS redirect"
  project     = var.project_id

  default_url_redirect {
    https_redirect         = true
    redirect_response_code = "MOVED_PERMANENTLY_DEFAULT"
    strip_query            = false
  }
}
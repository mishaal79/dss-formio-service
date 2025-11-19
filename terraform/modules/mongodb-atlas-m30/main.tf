# MongoDB Atlas M30 Dedicated Cluster Module
# Deploys MongoDB Atlas M30 Dedicated Cluster for Form.io Production

locals {
  # Standard labels
  common_labels = merge(var.labels, {
    service      = "mongodb-atlas"
    component    = "database"
    tier         = var.environment
    cluster_tier = "M30"
  })

  # Cluster tags (merging default with custom)
  cluster_tags = merge(var.cluster_tags, {
    project     = var.service_name
    environment = var.environment
    tier        = "M30"
  })
}

# =============================================================================
# MONGODB ATLAS RESOURCES
# =============================================================================

# MongoDB Atlas Project
resource "mongodbatlas_project" "main" {
  name   = var.atlas_project_name
  org_id = var.atlas_org_id

  tags = local.cluster_tags
}

# =============================================================================
# IP ACCESS LIST CONFIGURATION
# =============================================================================

# Allow access from Cloud Run/GCE instances via Cloud NAT static IPs
resource "mongodbatlas_project_ip_access_list" "cloud_nat" {
  count      = length(var.cloud_nat_static_ips)
  project_id = mongodbatlas_project.main.id
  cidr_block = "${var.cloud_nat_static_ips[count.index]}/32"
  comment    = "Cloud NAT static IP ${count.index + 1} for Cloud Run egress"
}

# Allow access from additional IP ranges (if any)
resource "mongodbatlas_project_ip_access_list" "additional" {
  for_each   = var.additional_ip_access_list
  project_id = mongodbatlas_project.main.id
  cidr_block = each.value.cidr_block
  comment    = each.value.comment
}

# Fallback: Allow all internet traffic if no specific IPs configured (NOT RECOMMENDED for production)
resource "mongodbatlas_project_ip_access_list" "internet_access" {
  count      = length(var.cloud_nat_static_ips) == 0 && length(var.additional_ip_access_list) == 0 ? 1 : 0
  project_id = mongodbatlas_project.main.id
  cidr_block = "0.0.0.0/0"
  comment    = "WARNING: Allow all internet traffic - configure specific IPs for production"
}

# Data sources to retrieve passwords from Secret Manager
data "google_secret_manager_secret_version" "admin_password" {
  secret  = var.admin_password_secret_id
  project = var.project_id
}

data "google_secret_manager_secret_version" "formio_password" {
  secret  = var.formio_password_secret_id
  project = var.project_id
}

# MongoDB Atlas M30 Dedicated Cluster
resource "mongodbatlas_cluster" "main" {
  project_id = mongodbatlas_project.main.id
  name       = var.cluster_name

  # Dedicated Cluster Configuration (M30)
  cluster_type = "REPLICASET"

  # Provider Settings
  provider_name               = var.backing_provider_name
  provider_instance_size_name = var.cluster_tier
  provider_region_name        = var.atlas_region_name

  # MongoDB Version
  mongo_db_major_version = var.mongodb_version

  # Backup Configuration
  cloud_backup = var.backup_enabled
  pit_enabled  = var.pit_enabled

  # Auto-scaling configuration (for M30 tier)
  auto_scaling_disk_gb_enabled = var.auto_scaling_disk_gb_enabled

  # Advanced Configuration
  advanced_configuration {
    javascript_enabled                   = var.javascript_enabled
    oplog_size_mb                        = var.oplog_size_mb
    sample_size_bi_connector             = var.sample_size_bi_connector
    sample_refresh_interval_bi_connector = var.sample_refresh_interval_bi_connector
  }

  # Termination Protection
  termination_protection_enabled = var.termination_protection_enabled

  # Labels
  labels {
    key   = "environment"
    value = var.environment
  }

  labels {
    key   = "project"
    value = var.service_name
  }

  labels {
    key   = "managed_by"
    value = "terraform"
  }

  labels {
    key   = "tier"
    value = "M30"
  }
}

# =============================================================================
# DATABASE USERS
# =============================================================================

# MongoDB Atlas Admin User
resource "mongodbatlas_database_user" "admin" {
  username           = var.admin_username
  password           = data.google_secret_manager_secret_version.admin_password.secret_data
  project_id         = mongodbatlas_project.main.id
  auth_database_name = "admin"

  roles {
    role_name     = "atlasAdmin"
    database_name = "admin"
  }

  scopes {
    name = mongodbatlas_cluster.main.name
    type = "CLUSTER"
  }
}

# MongoDB Atlas Form.io User for Community Database
resource "mongodbatlas_database_user" "formio_community" {
  username           = "${var.formio_username}_community"
  password           = data.google_secret_manager_secret_version.formio_password.secret_data
  project_id         = mongodbatlas_project.main.id
  auth_database_name = "admin"

  roles {
    role_name     = "readWrite"
    database_name = var.community_database_name
  }

  scopes {
    name = mongodbatlas_cluster.main.name
    type = "CLUSTER"
  }
}

# MongoDB Atlas Form.io User for Enterprise Database
resource "mongodbatlas_database_user" "formio_enterprise" {
  username           = "${var.formio_username}_enterprise"
  password           = data.google_secret_manager_secret_version.formio_password.secret_data
  project_id         = mongodbatlas_project.main.id
  auth_database_name = "admin"

  roles {
    role_name     = "readWrite"
    database_name = var.enterprise_database_name
  }

  scopes {
    name = mongodbatlas_cluster.main.name
    type = "CLUSTER"
  }
}

# MongoDB Atlas Read-Only User for Monitoring
resource "mongodbatlas_database_user" "monitoring" {
  username           = "${var.formio_username}_monitoring"
  password           = data.google_secret_manager_secret_version.formio_password.secret_data
  project_id         = mongodbatlas_project.main.id
  auth_database_name = "admin"

  roles {
    role_name     = "read"
    database_name = var.community_database_name
  }

  roles {
    role_name     = "read"
    database_name = var.enterprise_database_name
  }

  roles {
    role_name     = "clusterMonitor"
    database_name = "admin"
  }

  scopes {
    name = mongodbatlas_cluster.main.name
    type = "CLUSTER"
  }
}

# =============================================================================
# SECRET MANAGER INTEGRATION
# MongoDB connection strings for Form.io services
# =============================================================================

# Connection string for Community database
resource "google_secret_manager_secret" "mongodb_community_connection_string" {
  secret_id = "${var.service_name}-mongodb-community-connection-string-${var.environment}"
  project   = var.project_id

  labels = local.common_labels

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "mongodb_community_connection_string" {
  secret = google_secret_manager_secret.mongodb_community_connection_string.id
  # Construct proper MongoDB SRV connection string with authentication and database
  secret_data = "${replace(mongodbatlas_cluster.main.connection_strings[0].standard_srv, "mongodb+srv://", "mongodb+srv://${urlencode(mongodbatlas_database_user.formio_community.username)}:${urlencode(data.google_secret_manager_secret_version.formio_password.secret_data)}@")}/${var.community_database_name}?retryWrites=true&w=majority"
}

# Connection string for Enterprise database
resource "google_secret_manager_secret" "mongodb_enterprise_connection_string" {
  secret_id = "${var.service_name}-mongodb-enterprise-connection-string-${var.environment}"
  project   = var.project_id

  labels = local.common_labels

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "mongodb_enterprise_connection_string" {
  secret = google_secret_manager_secret.mongodb_enterprise_connection_string.id
  # Construct proper MongoDB SRV connection string with authentication and database
  secret_data = "${replace(mongodbatlas_cluster.main.connection_strings[0].standard_srv, "mongodb+srv://", "mongodb+srv://${urlencode(mongodbatlas_database_user.formio_enterprise.username)}:${urlencode(data.google_secret_manager_secret_version.formio_password.secret_data)}@")}/${var.enterprise_database_name}?retryWrites=true&w=majority"
}

# Connection string for Admin user (for management tasks)
resource "google_secret_manager_secret" "mongodb_admin_connection_string" {
  secret_id = "${var.service_name}-mongodb-admin-connection-string-${var.environment}"
  project   = var.project_id

  labels = local.common_labels

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "mongodb_admin_connection_string" {
  secret = google_secret_manager_secret.mongodb_admin_connection_string.id
  # Construct proper MongoDB SRV connection string for admin user
  secret_data = "${replace(mongodbatlas_cluster.main.connection_strings[0].standard_srv, "mongodb+srv://", "mongodb+srv://${urlencode(mongodbatlas_database_user.admin.username)}:${urlencode(data.google_secret_manager_secret_version.admin_password.secret_data)}@")}/admin?retryWrites=true&w=majority"
}

# Connection string for Monitoring user
resource "google_secret_manager_secret" "mongodb_monitoring_connection_string" {
  secret_id = "${var.service_name}-mongodb-monitoring-connection-string-${var.environment}"
  project   = var.project_id

  labels = local.common_labels

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "mongodb_monitoring_connection_string" {
  secret = google_secret_manager_secret.mongodb_monitoring_connection_string.id
  # Construct proper MongoDB SRV connection string for monitoring user
  secret_data = "${replace(mongodbatlas_cluster.main.connection_strings[0].standard_srv, "mongodb+srv://", "mongodb+srv://${urlencode(mongodbatlas_database_user.monitoring.username)}:${urlencode(data.google_secret_manager_secret_version.formio_password.secret_data)}@")}/admin?retryWrites=true&w=majority"
}

# Legacy connection string for backward compatibility
resource "google_secret_manager_secret" "mongodb_connection_string" {
  secret_id = "${var.service_name}-mongodb-connection-string-${var.environment}"
  project   = var.project_id

  labels = local.common_labels

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "mongodb_connection_string" {
  secret = google_secret_manager_secret.mongodb_connection_string.id
  # Form.io expects standard MongoDB connection string format: mongodb://username:password@host:port/database?ssl=true
  secret_data = "mongodb://${urlencode(mongodbatlas_database_user.formio_community.username)}:${urlencode(data.google_secret_manager_secret_version.formio_password.secret_data)}@${replace(mongodbatlas_cluster.main.connection_strings[0].standard, "mongodb://", "")}/${var.community_database_name}?ssl=true"
}
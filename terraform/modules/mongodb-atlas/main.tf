# MongoDB Atlas Module
# Deploys MongoDB Atlas Flex Cluster for Form.io

locals {
  # Standard labels
  common_labels = merge(var.labels, {
    service   = "mongodb-atlas"
    component = "database"
    tier      = var.environment
  })

  # Cluster tags (merging default with custom)
  cluster_tags = merge(var.cluster_tags, {
    project     = var.service_name
    environment = var.environment
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

# Allow access from shared VPC egress subnet (secure connectivity)
resource "mongodbatlas_project_ip_access_list" "cloud_nat_access" {
  project_id = mongodbatlas_project.main.id
  cidr_block = var.cloud_nat_static_ip # Now contains CIDR range from egress subnet
  comment    = "Shared VPC egress subnet - secure Form.io connectivity via Cloud NAT"
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

# MongoDB Atlas Flex Cluster
resource "mongodbatlas_flex_cluster" "main" {
  project_id = mongodbatlas_project.main.id
  name       = var.cluster_name

  provider_settings = {
    backing_provider_name = var.backing_provider_name
    region_name           = var.atlas_region_name
  }

  termination_protection_enabled = var.termination_protection_enabled

  tags = local.cluster_tags
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
    name = mongodbatlas_flex_cluster.main.name
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
    name = mongodbatlas_flex_cluster.main.name
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
    name = mongodbatlas_flex_cluster.main.name
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
  secret_data = "${replace(mongodbatlas_flex_cluster.main.connection_strings.standard_srv, "mongodb+srv://", "mongodb+srv://${urlencode(mongodbatlas_database_user.formio_community.username)}:${urlencode(data.google_secret_manager_secret_version.formio_password.secret_data)}@")}/${var.community_database_name}?retryWrites=true&w=majority"
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
  secret_data = "${replace(mongodbatlas_flex_cluster.main.connection_strings.standard_srv, "mongodb+srv://", "mongodb+srv://${urlencode(mongodbatlas_database_user.formio_enterprise.username)}:${urlencode(data.google_secret_manager_secret_version.formio_password.secret_data)}@")}/${var.enterprise_database_name}?retryWrites=true&w=majority"
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
  secret_data = "mongodb://${urlencode(mongodbatlas_database_user.formio_community.username)}:${urlencode(data.google_secret_manager_secret_version.formio_password.secret_data)}@${replace(mongodbatlas_flex_cluster.main.connection_strings.standard, "mongodb://", "")}/${var.database_name}?ssl=true"
}
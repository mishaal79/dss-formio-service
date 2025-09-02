# TFLint Configuration for DSS Form.io Service
# Following Qrius GCP Methodology Standards


# Google Provider Rules
plugin "google" {
  enabled = true
  version = "0.29.0"
  source  = "github.com/terraform-linters/tflint-ruleset-google"
}

# Terraform Core Rules
plugin "terraform" {
  enabled = true
  version = "0.7.0"
  source  = "github.com/terraform-linters/tflint-ruleset-terraform"
  
  preset = "recommended"
}

# Naming Convention Rules - Comprehensive enforcement
rule "terraform_naming_convention" {
  enabled = true
  
  # Default format for most blocks
  format = "snake_case"
  
  # Variables should use snake_case (formio_license_key, mongodb_connection_string)
  variable {
    format = "snake_case"
  }
  
  # Outputs should use snake_case (formio_service_url, storage_bucket_name)
  output {
    format = "snake_case"
  }
  
  # Locals should use snake_case
  locals {
    format = "snake_case"
  }
  
  # Resources should use snake_case (formio_service, formio_service_account)
  resource {
    format = "snake_case"
  }
  
  # Data sources should use snake_case
  data {
    format = "snake_case"
  }
  
  # Modules should use kebab-case as per naming conventions
  module {
    custom = "^[a-z][a-z0-9-]*[a-z0-9]$"
  }
}

# Variable and Output Naming
rule "terraform_standard_module_structure" {
  enabled = true
}

rule "terraform_unused_declarations" {
  enabled = true
}

rule "terraform_unused_required_providers" {
  enabled = true
}

rule "terraform_required_version" {
  enabled = true
}

rule "terraform_required_providers" {
  enabled = true
}

# Documentation Rules
rule "terraform_documented_outputs" {
  enabled = true
}

rule "terraform_documented_variables" {
  enabled = true
}

# Security Rules
rule "terraform_deprecated_index" {
  enabled = true
}

rule "terraform_deprecated_interpolation" {
  enabled = true
}

rule "terraform_typed_variables" {
  enabled = true
}

# Google-specific Security and Validation Rules
rule "google_project_iam_member_invalid_member" {
  enabled = true
}

rule "google_project_iam_binding_invalid_member" {
  enabled = true
}

rule "google_project_iam_audit_config_invalid_member" {
  enabled = true
}

rule "google_project_iam_policy_invalid_member" {
  enabled = true
}

# Cost Optimization Rules
rule "google_compute_instance_invalid_machine_type" {
  enabled = true
}

rule "google_container_cluster_invalid_machine_type" {
  enabled = true
}

rule "google_container_node_pool_invalid_machine_type" {
  enabled = true
}


# Custom validation rules for our specific use case
rule "terraform_workspace_remote" {
  enabled = true
}

# Module-specific rules
rule "terraform_module_pinned_source" {
  enabled = true
  style   = "semver"
}

config {
  # Enable module inspection
  call_module_type = "all"
  
  # Fail on warnings
  force = false
  
  # Disable color output for CI/CD
  disabled_by_default = false
}
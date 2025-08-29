# Makefile for DSS Form.io Service
#
# This Makefile provides a standardized workflow for managing Form.io service deployments.
# It uses Terraform as the single source of truth for all configuration values.
# Infrastructure is managed via Terraform, while application deployments use gcloud.
#
# Workflow:
#   1. Infrastructure: make init → make plan → make apply
#   2. Applications: make deploy-ent IMG=image:tag (or use configured defaults)
#   3. Monitoring: make status, make logs-ent

# =============================================================================
# ENVIRONMENT CONFIGURATION
# =============================================================================

# Environment targeting (default: dev)
ENV ?= dev
TF_DIR := terraform/environments/$(ENV)

# Use bash with strict error handling
SHELL := /bin/bash
.SHELLFLAGS := -ec

# =============================================================================
# DYNAMIC CONFIGURATION FROM TERRAFORM
# =============================================================================
# All configuration values are read from Terraform outputs, establishing
# Terraform as the single source of truth. Defaults are only used if
# Terraform has not been initialized yet.

# Helper function to read Terraform outputs
define tf_output
$(shell cd $(TF_DIR) 2>/dev/null && terraform output -raw $(1) 2>/dev/null || echo $(2))
endef

# Project configuration from Terraform
PROJECT_ID := $(call tf_output,project_id,erlich-dev)
REGION := $(call tf_output,region,australia-southeast1)

# Service names from Terraform
SERVICE_ENT := $(call tf_output,enterprise_service_name_full,dss-formio-api-ent-$(ENV))
SERVICE_COM := $(call tf_output,community_service_name_full,dss-formio-api-com-$(ENV))

# Docker images from Terraform (configured versions)
IMG_ENT_CONFIGURED := $(call tf_output,enterprise_image_configured,formio/formio-enterprise:9.6.0-rc.4)
IMG_COM_CONFIGURED := $(call tf_output,community_image_configured,formio/formio:rc)

# Docker images from Terraform (deployed versions)
IMG_ENT_DEPLOYED := $(call tf_output,enterprise_image_deployed,)
IMG_COM_DEPLOYED := $(call tf_output,community_image_deployed,)

# Default images for deployment (use configured unless overridden)
IMG_ENT ?= $(IMG_ENT_CONFIGURED)
IMG_COM ?= $(IMG_COM_CONFIGURED)

# Database names from Terraform
DB_ENT := $(call tf_output,enterprise_database_name,formio_enterprise)
DB_COM := $(call tf_output,community_database_name,formio_community)

# =============================================================================
# HELP & DOCUMENTATION
# =============================================================================

.PHONY: help
help: ## Show this help message
	@echo "DSS Form.io Service Management"
	@echo ""
	@echo "Current Configuration (from Terraform):"
	@echo "  Environment: $(ENV)"
	@echo "  Project:     $(PROJECT_ID)"
	@echo "  Region:      $(REGION)"
	@echo ""
	@echo "Infrastructure Management (Terraform):"
	@grep -E '^(init|plan|apply|destroy|check|security|format|lint|test):.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-20s %s\n", $$1, $$2}'
	@echo ""
	@echo "Application Deployment (gcloud):"
	@grep -E '^(deploy-|update-|traffic-):.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-20s %s\n", $$1, $$2}'
	@echo ""
	@echo "Monitoring & Operations:"
	@grep -E '^(status|logs-|health-|show-|atlas-):.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-20s %s\n", $$1, $$2}'
	@echo ""
	@echo "Examples:"
	@echo "  make deploy-ent                  # Deploy enterprise using configured version"
	@echo "  make deploy-ent IMG=image:9.5.1  # Deploy specific version"
	@echo "  make show-versions               # Show configured vs deployed versions"

# =============================================================================
# INFRASTRUCTURE MANAGEMENT (TERRAFORM)
# =============================================================================

.PHONY: init
init: ## Initialize Terraform
	@echo "--> Initializing Terraform for $(ENV)..."
	@terraform -chdir=$(TF_DIR) init -input=false -reconfigure

.PHONY: plan
plan: init check ## Plan infrastructure changes
	@echo "--> Generating plan for $(ENV)..."
	@terraform -chdir=$(TF_DIR) plan -out=tfplan.out -input=false

.PHONY: apply
apply: init validate-env ## Apply infrastructure changes
	@echo "--> Applying changes for $(ENV)..."
	@if [ ! -f "$(TF_DIR)/tfplan.out" ]; then \
		echo "Error: No plan file found. Run 'make plan' first."; \
		exit 1; \
	fi
	@terraform -chdir=$(TF_DIR) apply -auto-approve tfplan.out
	@echo "✅ Infrastructure updated. Configuration available for Makefile commands."

.PHONY: destroy
destroy: init validate-env ## Destroy infrastructure (requires confirmation)
	@echo "--> Planning destruction for $(ENV)..."
	@terraform -chdir=$(TF_DIR) plan -destroy -out=destroy.tfplan -input=false
	@read -p "⚠️  Are you sure you want to destroy $(ENV)? Type 'yes' to confirm: " confirm; \
	if [ "$$confirm" = "yes" ]; then \
		terraform -chdir=$(TF_DIR) apply -auto-approve destroy.tfplan; \
		echo "Infrastructure destroyed."; \
	else \
		echo "Destruction cancelled."; \
		rm -f $(TF_DIR)/destroy.tfplan; \
	fi

# =============================================================================
# QUALITY & VALIDATION
# =============================================================================

.PHONY: validate-env
validate-env:
	@if [ ! -d "$(TF_DIR)" ]; then \
		echo "Error: Environment '$(ENV)' not found at $(TF_DIR)"; \
		echo "Available environments:"; \
		ls -1 terraform/environments/ | sed 's/^/  - /'; \
		exit 1; \
	fi

.PHONY: check
check: format lint ## Run all quality checks

.PHONY: format
format: ## Format Terraform code
	@echo "--> Formatting Terraform code..."
	@terraform fmt -recursive terraform/

.PHONY: lint
lint: init ## Lint Terraform code
	@echo "--> Linting Terraform code..."
	@if command -v tflint >/dev/null 2>&1; then \
		tflint --config=.tflint.hcl --chdir=terraform/; \
	else \
		echo "tflint not installed, skipping..."; \
	fi

.PHONY: security
security: ## Run security scans
	@echo "--> Running security scans..."
	@if command -v checkov >/dev/null 2>&1; then \
		checkov -d terraform/ --framework terraform --compact; \
	elif command -v uvx >/dev/null 2>&1; then \
		uvx checkov -d terraform/ --framework terraform --compact; \
	else \
		echo "checkov not available, skipping..."; \
	fi

.PHONY: test
test: ## Run Terraform tests
	@echo "--> Running tests..."
	@./scripts/run-tests.sh mock

# =============================================================================
# APPLICATION DEPLOYMENT (GCLOUD)
# =============================================================================

.PHONY: deploy-ent
deploy-ent: validate-deployment ## Deploy Enterprise edition
	@echo "--> Deploying Enterprise edition..."
	@echo "    Image: $(IMG_ENT)"
	@echo "    Service: $(SERVICE_ENT)"
	@gcloud run deploy $(SERVICE_ENT) \
		--image=$(IMG_ENT) \
		--region=$(REGION) \
		--project=$(PROJECT_ID)
	@echo "✅ Enterprise edition deployed: $(IMG_ENT)"

.PHONY: deploy-com
deploy-com: validate-deployment ## Deploy Community edition
	@echo "--> Deploying Community edition..."
	@echo "    Image: $(IMG_COM)"
	@echo "    Service: $(SERVICE_COM)"
	@gcloud run deploy $(SERVICE_COM) \
		--image=$(IMG_COM) \
		--region=$(REGION) \
		--project=$(PROJECT_ID)
	@echo "✅ Community edition deployed: $(IMG_COM)"

.PHONY: deploy-all
deploy-all: deploy-ent deploy-com ## Deploy both editions

.PHONY: deploy-configured
deploy-configured: ## Deploy using Terraform's configured versions
	@echo "--> Deploying configured versions from Terraform..."
	@if [ -n "$(IMG_ENT_CONFIGURED)" ] && [ "$(IMG_ENT_CONFIGURED)" != "" ]; then \
		$(MAKE) deploy-ent IMG_ENT=$(IMG_ENT_CONFIGURED); \
	fi
	@if [ -n "$(IMG_COM_CONFIGURED)" ] && [ "$(IMG_COM_CONFIGURED)" != "" ]; then \
		$(MAKE) deploy-com IMG_COM=$(IMG_COM_CONFIGURED); \
	fi

# =============================================================================
# IN-PLACE UPDATES (ENVIRONMENT VARIABLES)
# =============================================================================

.PHONY: update-ent
update-ent: require-terraform-outputs ## Update Enterprise service environment variables
	@echo "--> Updating Enterprise service environment variables from Terraform..."
	@ENV_VARS=$$(cd $(TF_DIR) && terraform output -raw enterprise_env_vars 2>/dev/null | sed 's/\\//g') && \
	if [ -z "$$ENV_VARS" ]; then \
		echo "Error: No environment variables found. Ensure Enterprise is deployed in Terraform."; \
		exit 1; \
	else \
		gcloud run services update $(SERVICE_ENT) \
			--update-env-vars "$$ENV_VARS" \
			--region=$(REGION) \
			--project=$(PROJECT_ID) && \
		echo "✅ Environment variables updated successfully"; \
	fi

.PHONY: update-com
update-com: require-terraform-outputs ## Update Community service environment variables
	@echo "--> Updating Community service environment variables from Terraform..."
	@ENV_VARS=$$(cd $(TF_DIR) && terraform output -raw community_env_vars 2>/dev/null | sed 's/\\//g') && \
	if [ -z "$$ENV_VARS" ]; then \
		echo "Error: No environment variables found. Ensure Community is deployed in Terraform."; \
		exit 1; \
	else \
		gcloud run services update $(SERVICE_COM) \
			--update-env-vars "$$ENV_VARS" \
			--region=$(REGION) \
			--project=$(PROJECT_ID) && \
		echo "✅ Environment variables updated successfully"; \
	fi

.PHONY: update-ent-full
update-ent-full: require-terraform-outputs ## Update Enterprise with new image and environment variables
	@echo "--> Updating Enterprise service with image and environment variables..."
	@ENV_VARS=$$(cd $(TF_DIR) && terraform output -raw enterprise_env_vars 2>/dev/null | sed 's/\\//g') && \
	if [ -z "$$ENV_VARS" ]; then \
		echo "Error: No environment variables found. Run 'make apply' first."; \
		exit 1; \
	else \
		gcloud run services update $(SERVICE_ENT) \
			--image=$(IMG_ENT) \
			--update-env-vars "$$ENV_VARS" \
			--region=$(REGION) \
			--project=$(PROJECT_ID) && \
		echo "✅ Service updated with image $(IMG_ENT)"; \
	fi

# =============================================================================
# TRAFFIC MANAGEMENT
# =============================================================================

.PHONY: traffic-ent-100
traffic-ent-100: ## Route 100% traffic to Enterprise latest revision
	@echo "--> Routing 100% traffic to Enterprise latest revision..."
	@gcloud run services update-traffic $(SERVICE_ENT) \
		--to-latest \
		--region=$(REGION) \
		--project=$(PROJECT_ID)
	@echo "✅ Traffic routed to latest Enterprise revision"

.PHONY: traffic-com-100
traffic-com-100: ## Route 100% traffic to Community latest revision
	@echo "--> Routing 100% traffic to Community latest revision..."
	@gcloud run services update-traffic $(SERVICE_COM) \
		--to-latest \
		--region=$(REGION) \
		--project=$(PROJECT_ID)
	@echo "✅ Traffic routed to latest Community revision"

# =============================================================================
# MONITORING & OPERATIONS
# =============================================================================

.PHONY: status
status: ## Show service status
	@echo "=== Form.io Service Status ==="
	@echo ""
	@echo "Environment: $(ENV)"
	@echo "Project:     $(PROJECT_ID)"
	@echo "Region:      $(REGION)"
	@echo ""
	@if [ -n "$(SERVICE_ENT)" ] && [ "$(SERVICE_ENT)" != "" ]; then \
		echo "=== Enterprise Edition ==="; \
		gcloud run services describe $(SERVICE_ENT) \
			--region=$(REGION) \
			--project=$(PROJECT_ID) \
			--format="value(status.url,status.conditions[0].message)" 2>/dev/null || echo "Not deployed"; \
	fi
	@if [ -n "$(SERVICE_COM)" ] && [ "$(SERVICE_COM)" != "" ]; then \
		echo ""; \
		echo "=== Community Edition ==="; \
		gcloud run services describe $(SERVICE_COM) \
			--region=$(REGION) \
			--project=$(PROJECT_ID) \
			--format="value(status.url,status.conditions[0].message)" 2>/dev/null || echo "Not deployed"; \
	fi

.PHONY: show-versions
show-versions: ## Show configured vs deployed image versions
	@echo "=== Image Version Comparison ==="
	@echo ""
	@echo "Enterprise Edition:"
	@echo "  Configured: $(IMG_ENT_CONFIGURED)"
	@if [ -n "$(IMG_ENT_DEPLOYED)" ] && [ "$(IMG_ENT_DEPLOYED)" != "" ]; then \
		echo "  Deployed:   $(IMG_ENT_DEPLOYED)"; \
	else \
		echo "  Deployed:   Not deployed or Terraform not applied"; \
	fi
	@echo ""
	@echo "Community Edition:"
	@echo "  Configured: $(IMG_COM_CONFIGURED)"
	@if [ -n "$(IMG_COM_DEPLOYED)" ] && [ "$(IMG_COM_DEPLOYED)" != "" ]; then \
		echo "  Deployed:   $(IMG_COM_DEPLOYED)"; \
	else \
		echo "  Deployed:   Not deployed or Terraform not applied"; \
	fi

.PHONY: logs-ent
logs-ent: ## Show Enterprise service logs
	@echo "--> Fetching Enterprise service logs..."
	@gcloud logging read "resource.type=cloud_run_revision AND resource.labels.service_name=$(SERVICE_ENT)" \
		--project=$(PROJECT_ID) \
		--limit=50 \
		--format="table(timestamp,severity,jsonPayload.message)"

.PHONY: logs-com
logs-com: ## Show Community service logs
	@echo "--> Fetching Community service logs..."
	@gcloud logging read "resource.type=cloud_run_revision AND resource.labels.service_name=$(SERVICE_COM)" \
		--project=$(PROJECT_ID) \
		--limit=50 \
		--format="table(timestamp,severity,jsonPayload.message)"

.PHONY: health-check
health-check: ## Run comprehensive health check
	@echo "--> Running health check..."
	@if [ -f "./scripts/health-check.sh" ]; then \
		./scripts/health-check.sh; \
	else \
		echo "Health check script not found"; \
	fi

# =============================================================================
# MONGODB ATLAS MANAGEMENT
# =============================================================================

.PHONY: atlas-status
atlas-status: require-terraform-outputs ## Show MongoDB Atlas cluster status
	@echo "=== MongoDB Atlas Status ==="
	@cd $(TF_DIR) && terraform output -json | jq -r 'with_entries(select(.key | startswith("mongodb_atlas"))) | to_entries[] | "\(.key): \(.value.value)"'

.PHONY: atlas-init
atlas-init: ## Initialize MongoDB Atlas databases
	@echo "--> Initializing MongoDB Atlas databases..."
	@if [ -f "./scripts/init-atlas-databases.sh" ]; then \
		./scripts/init-atlas-databases.sh; \
	else \
		echo "Atlas initialization script not found"; \
	fi

# =============================================================================
# DEVELOPMENT WORKFLOW
# =============================================================================

.PHONY: dev-setup
dev-setup: init plan ## Complete development environment setup
	@echo "✅ Development environment ready. Run 'make apply' to create infrastructure."

.PHONY: restart-services
restart-services: ## Restart Cloud Run services to pick up new configurations
	@echo "--> Restarting services..."
	@if [ -n "$(SERVICE_ENT)" ] && [ "$(SERVICE_ENT)" != "" ]; then \
		gcloud run services update $(SERVICE_ENT) --region=$(REGION) --project=$(PROJECT_ID) --no-traffic; \
		echo "✅ Enterprise service restarted"; \
	fi
	@if [ -n "$(SERVICE_COM)" ] && [ "$(SERVICE_COM)" != "" ]; then \
		gcloud run services update $(SERVICE_COM) --region=$(REGION) --project=$(PROJECT_ID) --no-traffic; \
		echo "✅ Community service restarted"; \
	fi

# =============================================================================
# UTILITY TARGETS
# =============================================================================

.PHONY: validate-deployment
validate-deployment:
	@if [ -z "$(PROJECT_ID)" ] || [ "$(PROJECT_ID)" = "" ]; then \
		echo "Error: Unable to read project configuration from Terraform."; \
		echo "Run 'make init' and 'make apply' first to initialize infrastructure."; \
		exit 1; \
	fi

.PHONY: require-terraform-outputs
require-terraform-outputs:
	@if ! cd $(TF_DIR) 2>/dev/null && terraform output -json >/dev/null 2>&1; then \
		echo "Error: Terraform outputs not available."; \
		echo "Run 'make apply' first to create infrastructure and generate outputs."; \
		exit 1; \
	fi

.PHONY: clean
clean: ## Clean up temporary files
	@echo "--> Cleaning up temporary files..."
	@find terraform -name "*.tfplan" -delete
	@find terraform -name "tfplan.out" -delete
	@find terraform -name "destroy.tfplan" -delete
	@find terraform -name ".terraform.lock.hcl" -delete
	@echo "✅ Cleanup complete"

.PHONY: clean-all
clean-all: clean ## Deep clean including Terraform state (destructive!)
	@echo "⚠️  WARNING: This will remove Terraform state files!"
	@read -p "Are you sure? Type 'yes' to confirm: " confirm; \
	if [ "$$confirm" = "yes" ]; then \
		find terraform -type d -name ".terraform" -exec rm -rf {} + 2>/dev/null || true; \
		find terraform -name "terraform.tfstate*" -delete; \
		echo "✅ Deep cleanup complete"; \
	else \
		echo "Cleanup cancelled"; \
	fi

# =============================================================================
# DEFAULT TARGET
# =============================================================================

.DEFAULT_GOAL := help
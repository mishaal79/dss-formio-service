# DSS Form.io Service - Makefile
# Separation of concerns: Terraform for infrastructure, gcloud for applications

# Variables
PROJECT_ID ?= erlich-dev
REGION ?= australia-southeast1
ENV ?= dev
SERVICE_COM = dss-formio-api-com-$(ENV)
SERVICE_ENT = dss-formio-api-ent-$(ENV)

# Default image versions
IMG_COM ?= formio/formio:v4.6.0-rc.3
IMG_ENT ?= formio/formio-enterprise:9.5.1-rc.10

# Common terraform directories
TF_ROOT = terraform
TF_ENV_DIR = $(TF_ROOT)/environments/$(ENV)

.PHONY: help infra-* deploy-* test format

help: ## Show available commands
	@echo "Infrastructure (Terraform):"
	@echo "  make infra-plan    - Plan infrastructure changes"
	@echo "  make infra-apply   - Apply infrastructure changes"
	@echo "  make infra-destroy - Destroy infrastructure"
	@echo ""
	@echo "Application Deployment (gcloud):"
	@echo "  make deploy-com IMG=image:tag - Deploy Community edition"
	@echo "  make deploy-ent IMG=image:tag - Deploy Enterprise edition"
	@echo "  make deploy-all               - Deploy both editions"
	@echo ""
	@echo "Development:"
	@echo "  make dev-setup     - Complete dev environment setup"
	@echo "  make test          - Run terraform tests"
	@echo "  make format        - Format and lint terraform"

# Infrastructure Management (Terraform)
infra-plan: ## Plan terraform infrastructure changes
	cd $(TF_ENV_DIR) && terraform plan -out=tfplan.out

infra-apply: ## Apply terraform infrastructure changes
	cd $(TF_ENV_DIR) && terraform apply -auto-approve tfplan.out

infra-destroy: ## Destroy terraform infrastructure
	cd $(TF_ENV_DIR) && terraform destroy

infra-init: ## Initialize terraform
	cd $(TF_ENV_DIR) && terraform init

# Application Deployment (gcloud)
deploy-com: ## Deploy Community edition (usage: make deploy-com IMG=formio/formio:tag)
	gcloud run deploy $(SERVICE_COM) \
		--image=$(IMG_COM) \
		--region=$(REGION) \
		--project=$(PROJECT_ID)

deploy-ent: ## Deploy Enterprise edition (usage: make deploy-ent IMG=formio/formio-enterprise:tag)
	gcloud run deploy $(SERVICE_ENT) \
		--image=$(IMG_ENT) \
		--region=$(REGION) \
		--project=$(PROJECT_ID)

deploy-all: deploy-com deploy-ent ## Deploy both Community and Enterprise editions

# Traffic Management
traffic-com-100: ## Route 100% traffic to Community edition
	gcloud run services update-traffic $(SERVICE_COM) \
		--to-latest \
		--region=$(REGION) \
		--project=$(PROJECT_ID)

traffic-ent-100: ## Route 100% traffic to Enterprise edition
	gcloud run services update-traffic $(SERVICE_ENT) \
		--to-latest \
		--region=$(REGION) \
		--project=$(PROJECT_ID)

# Development Workflow
dev-setup: infra-init infra-plan ## Complete dev environment setup
	@echo "Dev environment initialized. Run 'make infra-apply' to create infrastructure."

test: ## Run terraform tests (mock - no real resources)
	./scripts/run-tests.sh mock

format: ## Format and lint terraform code
	terraform fmt -recursive $(TF_ROOT)
	tflint --config=../.tflint.hcl --chdir=$(TF_ROOT)

# Service Management
logs-com: ## Show Community service logs
	gcloud logging read "resource.type=cloud_run_revision AND resource.labels.service_name=$(SERVICE_COM)" \
		--project=$(PROJECT_ID) --limit=50

logs-ent: ## Show Enterprise service logs
	gcloud logging read "resource.type=cloud_run_revision AND resource.labels.service_name=$(SERVICE_ENT)" \
		--project=$(PROJECT_ID) --limit=50

status: ## Show service status
	@echo "=== Community Edition ==="
	gcloud run services describe $(SERVICE_COM) --region=$(REGION) --project=$(PROJECT_ID) --format="value(status.url,status.conditions[0].message)"
	@echo "=== Enterprise Edition ==="
	gcloud run services describe $(SERVICE_ENT) --region=$(REGION) --project=$(PROJECT_ID) --format="value(status.url,status.conditions[0].message)"

# MongoDB Atlas Management
atlas-status: ## Show MongoDB Atlas cluster status
	@echo "=== MongoDB Atlas Status ==="
	cd $(TF_ENV_DIR) && terraform output mongodb_atlas_cluster_state mongodb_atlas_cluster_name mongodb_atlas_project_id

atlas-info: ## Show detailed Atlas information
	@echo "=== MongoDB Atlas Cluster Details ==="
	cd $(TF_ENV_DIR) && terraform output | grep mongodb_atlas

health-check: ## Run comprehensive health check
	./scripts/health-check.sh

restart-services: ## Restart Cloud Run services to pick up new secrets
	@echo "Restarting Cloud Run services..."
	gcloud run services update $(SERVICE_COM) --region=$(REGION) --project=$(PROJECT_ID)
	gcloud run services update $(SERVICE_ENT) --region=$(REGION) --project=$(PROJECT_ID)
	@echo "Services restarted. Use 'make status' to check status."
# =============================================================================
# TERRAFORM DEPLOYMENT MAKEFILE - FORM.IO CUSTOM SERVICE
# =============================================================================
# Clean, repeatable deployment workflow following Gemini's architectural guidance
#
# Usage:
#   make init     - Initialize Terraform backend
#   make plan     - Generate deployment plan
#   make deploy   - Deploy infrastructure
#   make destroy  - Destroy all resources
#   make output   - Show deployment outputs
#   make status   - Check service status
#   make logs     - Tail service logs
#   make health   - Check service health
#

.PHONY: help init plan deploy destroy output status logs health clean validate fmt

# Default target
.DEFAULT_GOAL := help

# Environment variables
PROJECT_ID := erlich-dev
REGION := australia-southeast1
ENVIRONMENT := dev
SERVICE_NAME := formio-custom-$(ENVIRONMENT)

# Colors for output
BLUE := \033[0;34m
GREEN := \033[0;32m
YELLOW := \033[0;33m
RED := \033[0;31m
NC := \033[0m # No Color

help: ## Show this help message
	@echo "$(BLUE)Form.io Custom Service - Terraform Deployment$(NC)"
	@echo ""
	@echo "$(GREEN)Available targets:$(NC)"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(YELLOW)%-15s$(NC) %s\n", $$1, $$2}'
	@echo ""
	@echo "$(GREEN)Quick Start:$(NC)"
	@echo "  make init && make plan && make deploy"
	@echo ""

init: ## Initialize Terraform backend
	@echo "$(BLUE)Initializing Terraform...$(NC)"
	terraform init
	@echo "$(GREEN)✓ Terraform initialized$(NC)"

validate: ## Validate Terraform configuration
	@echo "$(BLUE)Validating Terraform configuration...$(NC)"
	terraform validate
	@echo "$(GREEN)✓ Configuration valid$(NC)"

fmt: ## Format Terraform files
	@echo "$(BLUE)Formatting Terraform files...$(NC)"
	terraform fmt -recursive
	@echo "$(GREEN)✓ Files formatted$(NC)"

plan: validate ## Generate Terraform deployment plan
	@echo "$(BLUE)Generating Terraform plan...$(NC)"
	terraform plan -out=tfplan
	@echo ""
	@echo "$(GREEN)✓ Plan generated: tfplan$(NC)"
	@echo "$(YELLOW)Review the plan above, then run 'make deploy' to apply$(NC)"

deploy: ## Deploy infrastructure (requires plan)
	@if [ ! -f tfplan ]; then \
		echo "$(RED)✗ No plan file found. Run 'make plan' first.$(NC)"; \
		exit 1; \
	fi
	@echo "$(YELLOW)⚠️  This will create 21 resources in GCP project $(PROJECT_ID)$(NC)"
	@echo "$(YELLOW)⚠️  Press Ctrl+C to cancel, or Enter to continue...$(NC)"
	@read -p ""
	@echo "$(BLUE)Applying Terraform plan...$(NC)"
	terraform apply tfplan
	@rm -f tfplan
	@echo ""
	@echo "$(GREEN)✓ Deployment complete!$(NC)"
	@echo ""
	@$(MAKE) output

deploy-auto: plan ## Deploy automatically without confirmation (CI/CD)
	@echo "$(BLUE)Applying Terraform plan (auto-approve)...$(NC)"
	terraform apply -auto-approve tfplan
	@rm -f tfplan
	@echo "$(GREEN)✓ Deployment complete!$(NC)"
	@$(MAKE) output

output: ## Show deployment outputs
	@echo "$(BLUE)Deployment Outputs:$(NC)"
	@terraform output

output-json: ## Show deployment outputs in JSON format
	@terraform output -json

status: ## Check Cloud Run service status
	@echo "$(BLUE)Checking service status...$(NC)"
	@gcloud run services describe $(SERVICE_NAME) \
		--region=$(REGION) \
		--project=$(PROJECT_ID) \
		--format="table(status.conditions.type,status.conditions.status,status.conditions.reason)"

url: ## Get service URL
	@terraform output -raw service_url 2>/dev/null || \
		gcloud run services describe $(SERVICE_NAME) \
			--region=$(REGION) \
			--project=$(PROJECT_ID) \
			--format="value(status.url)"

health: url ## Check service health endpoint
	@SERVICE_URL=$$(terraform output -raw service_url 2>/dev/null); \
	if [ -z "$$SERVICE_URL" ]; then \
		echo "$(RED)✗ Service URL not found. Has the service been deployed?$(NC)"; \
		exit 1; \
	fi; \
	echo "$(BLUE)Checking health endpoint: $$SERVICE_URL/health$(NC)"; \
	curl -f -s -o /dev/null -w "HTTP %{http_code}\n" "$$SERVICE_URL/health" || \
		echo "$(YELLOW)⚠️  Health check failed (service may still be starting)$(NC)"

logs: ## Tail service logs
	@echo "$(BLUE)Tailing logs for $(SERVICE_NAME)...$(NC)"
	@gcloud logs tail "resource.type=cloud_run_revision AND resource.labels.service_name=$(SERVICE_NAME)" \
		--project=$(PROJECT_ID) \
		--format=default

logs-errors: ## Show recent error logs
	@echo "$(BLUE)Recent errors for $(SERVICE_NAME):$(NC)"
	@gcloud logs read "resource.type=cloud_run_revision AND resource.labels.service_name=$(SERVICE_NAME) AND severity>=ERROR" \
		--project=$(PROJECT_ID) \
		--limit=50 \
		--format=default

destroy: ## Destroy all infrastructure (DANGEROUS!)
	@echo "$(RED)⚠️  WARNING: This will DESTROY all resources!$(NC)"
	@echo "$(RED)⚠️  Service: $(SERVICE_NAME)$(NC)"
	@echo "$(RED)⚠️  Project: $(PROJECT_ID)$(NC)"
	@echo "$(YELLOW)Type 'yes' to confirm destruction:$(NC)"
	@read -p "" confirmation; \
	if [ "$$confirmation" = "yes" ]; then \
		echo "$(BLUE)Destroying infrastructure...$(NC)"; \
		terraform destroy -auto-approve; \
		echo "$(GREEN)✓ Infrastructure destroyed$(NC)"; \
	else \
		echo "$(YELLOW)Destruction cancelled$(NC)"; \
	fi

clean: ## Clean Terraform files and plan
	@echo "$(BLUE)Cleaning Terraform files...$(NC)"
	@rm -f tfplan
	@rm -rf .terraform.lock.hcl
	@echo "$(GREEN)✓ Cleaned$(NC)"

refresh: ## Refresh Terraform state
	@echo "$(BLUE)Refreshing Terraform state...$(NC)"
	terraform refresh
	@echo "$(GREEN)✓ State refreshed$(NC)"

show: ## Show Terraform state
	@terraform show

state-list: ## List resources in Terraform state
	@terraform state list

graph: ## Generate dependency graph
	@echo "$(BLUE)Generating dependency graph...$(NC)"
	terraform graph | dot -Tpng > /tmp/terraform-graph.png
	@echo "$(GREEN)✓ Graph saved to /tmp/terraform-graph.png$(NC)"

test: health ## Run post-deployment tests
	@echo "$(BLUE)Running post-deployment tests...$(NC)"
	@SERVICE_URL=$$(terraform output -raw service_url 2>/dev/null); \
	if [ -z "$$SERVICE_URL" ]; then \
		echo "$(RED)✗ Service URL not found$(NC)"; \
		exit 1; \
	fi; \
	echo "$(BLUE)Testing root endpoint...$(NC)"; \
	curl -f -s "$$SERVICE_URL/" > /dev/null && echo "$(GREEN)✓ Root endpoint OK$(NC)" || echo "$(RED)✗ Root endpoint failed$(NC)"; \
	echo "$(BLUE)Testing health endpoint...$(NC)"; \
	curl -f -s "$$SERVICE_URL/health" > /dev/null && echo "$(GREEN)✓ Health endpoint OK$(NC)" || echo "$(RED)✗ Health endpoint failed$(NC)"; \
	echo "$(GREEN)✓ Tests complete$(NC)"

info: ## Show deployment information
	@echo "$(BLUE)Deployment Information:$(NC)"
	@echo "  Project ID:   $(PROJECT_ID)"
	@echo "  Region:       $(REGION)"
	@echo "  Environment:  $(ENVIRONMENT)"
	@echo "  Service Name: $(SERVICE_NAME)"
	@echo ""
	@echo "$(BLUE)Terraform State:$(NC)"
	@echo "  Backend: GCS"
	@echo "  Bucket:  dss-org-tf-state"
	@echo "  Prefix:  formio-service/environments/dev-formio-custom"
	@echo ""
	@if [ -f tfplan ]; then \
		echo "$(GREEN)✓ Plan file exists: tfplan$(NC)"; \
	else \
		echo "$(YELLOW)⚠ No plan file found$(NC)"; \
	fi

# Full deployment workflow
full-deploy: clean init plan deploy test ## Complete deployment workflow (clean, init, plan, deploy, test)
	@echo "$(GREEN)✓✓✓ Full deployment complete!$(NC)"

# Development workflow
dev: fmt validate plan ## Development workflow (format, validate, plan)
	@echo "$(GREEN)✓ Ready for deployment$(NC)"

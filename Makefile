.PHONY: help init fmt validate check plan clean

help: ## Display available commands
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

init: ## Initialize Terraform providers and backend
	terraform init -backend=false

fmt: ## Format Terraform configuration files
	terraform fmt -recursive

validate: ## Validate syntax and resource definitions
	terraform validate

check: fmt validate ## Run formatting check and validation

plan: ## Create execution plan
	terraform plan

clean: ## Remove temporary terraform runtime files
	rm -rf .terraform/providers

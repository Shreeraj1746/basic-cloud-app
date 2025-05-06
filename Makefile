.PHONY: help deploy destroy validate clean
.DEFAULT_GOAL := help

# Project variables
PROJECT_NAME := basic-cloud-app
TEMPLATE_DIR := infrastructure/templates
SCRIPTS_DIR := scripts
DEPLOY_SCRIPT := $(SCRIPTS_DIR)/deploy.sh
DESTROY_SCRIPT := $(SCRIPTS_DIR)/destroy.sh

help: ## Show this help
	@echo "Available commands:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

init: ## Make scripts executable
	@echo "Making scripts executable..."
	@chmod +x $(SCRIPTS_DIR)/*.sh
	@echo "Done."

validate: ## Validate CloudFormation templates
	@echo "Validating CloudFormation templates..."
	@for template in $(TEMPLATE_DIR)/*.yml; do \
		echo "Validating $$template"; \
		aws cloudformation validate-template --template-body file://$$template > /dev/null || exit 1; \
	done
	@echo "All templates are valid!"

deploy: init validate ## Deploy the CloudFormation stack
	@echo "Deploying CloudFormation stack..."
	@$(DEPLOY_SCRIPT)

destroy: init ## Destroy the CloudFormation stack
	@echo "Destroying CloudFormation stack..."
	@$(DESTROY_SCRIPT)

run-local: ## Run the Python application locally
	@echo "Running Python application locally..."
	@python3 app/app.py

clean: ## Clean temporary files
	@echo "Cleaning up temporary files..."
	@find . -name "*.tmp" -type f -delete
	@find . -name "*.bak" -type f -delete
	@find . -name "*.pyc" -type f -delete
	@find . -name "__pycache__" -type d -exec rm -rf {} +
	@echo "Done."

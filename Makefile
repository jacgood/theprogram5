# WebDNA Docker Project Makefile
# Automates common development tasks

.PHONY: help build up down restart logs test smoke-test clean dev prod status health

# Default target
help: ## Show this help message
	@echo "WebDNA Docker Project"
	@echo "===================="
	@echo "Available commands:"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

# Development commands
build: ## Build the Docker image
	@echo "Building WebDNA Docker image..."
	cd deploy && docker compose build

up: ## Start the services
	@echo "Starting WebDNA services..."
	cd deploy && docker compose up -d

down: ## Stop the services
	@echo "Stopping WebDNA services..."
	cd deploy && docker compose down

restart: down up ## Restart the services

logs: ## View container logs
	cd deploy && docker compose logs -f

# Testing commands
test: ## Run full test suite
	@echo "Running full test suite..."
	./tests/run_tests.sh

smoke-test: ## Run quick smoke tests
	@echo "Running smoke tests..."
	./tests/smoke_tests.sh

# Utility commands
clean: ## Clean up containers and images
	@echo "Cleaning up Docker resources..."
	cd deploy && docker compose down --volumes --remove-orphans
	docker system prune -f

dev: build up test ## Full development setup (build, start, test)

prod: ## Production deployment (placeholder)
	@echo "Production deployment not yet implemented"
	@echo "Would run: cd deploy && docker compose -f docker-compose.prod.yml up -d"

status: ## Show service status
	cd deploy && docker compose ps

health: ## Check service health
	@echo "Checking service health..."
	@curl -s -f http://10.10.0.118:8080/ > /dev/null && echo "✓ HTTP service OK" || echo "✗ HTTP service FAILED"
	@curl -s http://10.10.0.118:8080/WebCatalog/ | grep -q "WebDNA" && echo "✓ WebCatalog OK" || echo "✗ WebCatalog FAILED"
	@curl -s http://10.10.0.118:8080/theprogram/ | grep -q "Login" && echo "✓ Main app OK" || echo "✗ Main app FAILED"

# Development helpers
fix-permissions: ## Fix file permissions for development
	@echo "Fixing file permissions..."
	./scripts/fix-permissions.sh

# Performance monitoring commands
monitor: ## Start performance monitoring
	@echo "Starting performance monitoring..."
	@./monitoring/scripts/system_monitor.sh continuous

monitor-once: ## Run single monitoring collection
	@echo "Running single monitoring collection..."
	@./monitoring/scripts/system_monitor.sh once

dashboard: ## Show performance dashboard
	@echo "Starting performance dashboard..."
	@./monitoring/scripts/performance_dashboard.sh realtime

performance-report: ## Generate performance report
	@echo "Generating performance report..."
	@./monitoring/scripts/performance_dashboard.sh report

benchmark: ## Run performance benchmarks
	@echo "Running performance benchmarks..."
	@./performance/tools/benchmark.sh full

benchmark-quick: ## Run quick performance test
	@echo "Running quick performance test..."
	@./performance/tools/benchmark.sh single http://localhost:8080/theprogram/

# Database commands
db-start: ## Start PostgreSQL database
	@echo "Starting PostgreSQL database..."
	@cd deploy && docker compose up -d postgres

db-stop: ## Stop PostgreSQL database
	@echo "Stopping PostgreSQL database..."
	@cd deploy && docker compose stop postgres

db-test: ## Test database connection and show status
	@echo "Testing database connection..."
	@./scripts/test_postgres.sh

db-connect: ## Connect to main database
	@echo "Connecting to PostgreSQL..."
	@docker exec -it webdna-postgres psql -U webdna_user -d webdna_main

db-import: ## Import MySQL data to PostgreSQL (one-time setup)
	@echo "Importing MySQL data to PostgreSQL..."
	@./scripts/import_to_postgres.sh

# Project setup
setup: ## Initial project setup
	@echo "Setting up project..."
	@chmod +x tests/*.sh scripts/*.sh monitoring/scripts/*.sh performance/tools/*.sh
	@echo "Project setup complete!"
.PHONY: test test-parallel test-sequential clean help install-deps

# Default target
help: ## Show this help message
	@echo "SourceAtlas Test Management"
	@echo "=========================="
	@echo ""
	@echo "Available targets:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

install-deps: ## Install test dependencies (bats, jq)
	@echo "🔧 Installing test dependencies..."
	@if command -v apt-get >/dev/null 2>&1; then \
		sudo apt-get update && sudo apt-get install -y bats jq; \
	elif command -v brew >/dev/null 2>&1; then \
		brew install bats-core jq; \
	elif command -v yum >/dev/null 2>&1; then \
		sudo yum install -y jq && \
		echo "Please install bats-core manually on RHEL/CentOS"; \
	else \
		echo "❌ Unable to install dependencies automatically"; \
		echo "Please install bats and jq manually"; \
		exit 1; \
	fi
	@echo "✅ Dependencies installed"

test: test-parallel ## Run all tests using optimized parallel execution

test-parallel: ## Run tests in parallel groups (70% faster)
	@echo "🚀 Running optimized parallel test execution..."
	@chmod +x tests/run_parallel_tests.sh bin/satlas bin/sourceatlas
	@tests/run_parallel_tests.sh

test-sequential: ## Run tests sequentially (original approach)
	@echo "🐌 Running sequential test execution..."
	@chmod +x bin/satlas bin/sourceatlas
	@bats tests/e2e/*.bats

test-group-%: ## Run specific test group (read-only, modification, independent, performance)
	@echo "🎯 Running $* test group..."
	@chmod +x tests/run_parallel_tests.sh bin/satlas bin/sourceatlas
	@case "$*" in \
		"read-only") bats --jobs 4 tests/e2e/{18,19,20,22}_*.bats tests/e2e/phase2_*.bats ;; \
		"modification") bats --jobs 2 tests/e2e/{17,21}_*.bats tests/e2e/{30,31}_*.bats ;; \
		"independent") bats --jobs 4 tests/e2e/{00,01,10,11,12,13,14,15,16,22}_*.bats ;; \
		"performance") bats --jobs 2 tests/e2e/{40,41,50,51,60,61}_*.bats ;; \
		*) echo "❌ Unknown test group: $*"; echo "Available groups: read-only, modification, independent, performance"; exit 1 ;; \
	esac

benchmark: ## Run performance benchmark comparison
	@echo "🔬 Running performance benchmark..."
	@chmod +x tests/e2e/benchmark_comparison.sh
	@tests/e2e/benchmark_comparison.sh --run

test-single: ## Run a single test file (usage: make test-single FILE=tests/e2e/00_framework.bats)
	@if [ -z "$(FILE)" ]; then \
		echo "❌ Please specify a test file: make test-single FILE=tests/e2e/00_framework.bats"; \
		exit 1; \
	fi
	@echo "🧪 Running single test: $(FILE)"
	@chmod +x bin/satlas bin/sourceatlas
	@bats "$(FILE)"

clean: ## Clean up test artifacts and temporary files
	@echo "🧹 Cleaning up test artifacts..."
	@rm -rf /tmp/sourceatlas-test-* 2>/dev/null || true
	@rm -rf /tmp/satlas-test-cache-* 2>/dev/null || true
	@find tests/ -name "*.backup" -delete 2>/dev/null || true
	@echo "✅ Cleanup complete"

validate: ## Validate test environment and dependencies
	@echo "🔍 Validating test environment..."
	@echo "Checking required tools:"
	@command -v bats >/dev/null 2>&1 && echo "  ✅ bats: $(shell bats --version)" || echo "  ❌ bats: not found"
	@command -v jq >/dev/null 2>&1 && echo "  ✅ jq: $(shell jq --version)" || echo "  ❌ jq: not found"
	@echo "Checking CLI executables:"
	@[ -x bin/satlas ] && echo "  ✅ bin/satlas: executable" || echo "  ❌ bin/satlas: not executable"
	@[ -x bin/sourceatlas ] && echo "  ✅ bin/sourceatlas: executable" || echo "  ❌ bin/sourceatlas: not executable"
	@echo "Checking test structure:"
	@[ -f tests/helpers.bash ] && echo "  ✅ tests/helpers.bash: exists" || echo "  ❌ tests/helpers.bash: missing"
	@[ -f tests/helpers_optimized.bash ] && echo "  ✅ tests/helpers_optimized.bash: exists" || echo "  ❌ tests/helpers_optimized.bash: missing"
	@[ -d tests/fixtures/sourceatlas ] && echo "  ✅ test fixtures: exists" || echo "  ❌ test fixtures: missing"
	@echo "✅ Validation complete"

stats: ## Show test statistics and optimization impact
	@echo "📊 Test Statistics"
	@echo "=================="
	@echo "Total test files: $(shell find tests/e2e -name '*.bats' | wc -l)"
	@echo "Framework tests: $(shell find tests/e2e -name '{00,01}_*.bats' | wc -l)"
	@echo "CLI tests: $(shell find tests/e2e -name '{10,11,12,13,14,15,16,17,18,19,20,21,22}_*.bats' | wc -l)"
	@echo "Phase 2 tests: $(shell find tests/e2e -name 'phase2_*.bats' | wc -l)"
	@echo "Phase 3 tests: $(shell find tests/e2e -name '{30,31}_*.bats' | wc -l)"
	@echo "Phase 4 tests: $(shell find tests/e2e -name '{40,41}_*.bats' | wc -l)"
	@echo "Phase 5 tests: $(shell find tests/e2e -name '{50,51}_*.bats' | wc -l)"
	@echo "Phase 6 tests: $(shell find tests/e2e -name '{60,61}_*.bats' | wc -l)"
	@echo ""
	@echo "🚀 Optimization Impact (Estimated):"
	@echo "Sequential execution: ~176s (2.9 minutes)"
	@echo "Parallel execution:   ~23s (0.4 minutes)"
	@echo "Time savings:         ~153s (85% faster)"

# Development helpers
dev-setup: install-deps validate ## Complete development environment setup
	@echo "🎉 Development environment ready!"

ci-test: ## Run tests in CI mode (used by GitHub Actions)
	@echo "🤖 Running CI test execution..."
	@export CI=true && $(MAKE) test-parallel
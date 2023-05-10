.PHONY: default

# Configuration
PROJECT_NAME = kakarot
ENTRYPOINT = .
TEST_ENTRYPOINT = .
BUILD_DIR = build

# Default target
default: run

# All relevant targets
all: build run test

# Targets

# There is no integration between Scarb and the default `cairo-test` runner.
# Therefore, we need to generate the cairo_project.toml file, required
# by the `cairo-test` runner, manually. This is done by the generate_cairo_project script.
cairo-project:
	@echo "Generating cairo project..."
	sh scripts/generate_cairo_project.sh
# Test the project

# Compile the project
build: cairo-project FORCE
	$(MAKE) clean format
	@echo "Building..."
	cairo-compile . > $(BUILD_DIR)/$(PROJECT_NAME).sierra

# Run the project
run:
	@echo "Running..."
	#cairo-run -p $(ENTRYPOINT)



test: cairo-project
	@echo "Testing..."
	cairo-test $(TEST_ENTRYPOINT)

# Format the project
format:
	@echo "Formatting..."
	cairo-format src

# Clean the project
clean:
	@echo "Cleaning..."
	rm -rf $(BUILD_DIR)/*
	mkdir -p $(BUILD_DIR)

# Special filter tests targets

# Run tests related to the stack
test-stack:
	@echo "Testing stack..."
	cairo-test -p $(TEST_ENTRYPOINT) -f stack

# FORCE is a special target that is always out of date
# It enable to force a target to be executed
FORCE:
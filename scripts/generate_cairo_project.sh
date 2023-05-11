#!/bin/bash

# This script is used to generate the `cairo_project.toml` file
# from the Scarb project's metadata.
# It is required to run the `cairo-test` runner.

# Run the scarb metadata command and store the JSON output in a variable
json_output=$(scarb metadata --format-version 1| sed -n '/^{/,$p')

# Create a temporary file to store the JSON output
temp_file=$(mktemp)
echo "$json_output" > "$temp_file"

# Initialize cairo_project.toml file
echo "[crate_roots]" > cairo_project.toml

# Process the JSON output and create the cairo_project.toml file using jq
jq -r '.packages[] | select(.name != "core" and .name != "kakarot") | .name + " = \"" + .root + "/src\""' "$temp_file" >> cairo_project.toml

# Add kakarot and tests to the cairo_project.toml
echo 'kakarot = "src"' >> cairo_project.toml
echo 'tests = "tests"' >> cairo_project.toml

# Remove the temporary file
rm "$temp_file"
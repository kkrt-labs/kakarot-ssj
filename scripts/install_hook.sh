#!/bin/bash

# Define the hook content
HOOK_CONTENT='#!/bin/sh

# Run the compare_snapshot.py script
echo "Running gas snapshot comparison..."
python scripts/compare_snapshot.py

# Check the return status of the script
if [ $? -ne 0 ]; then
    echo "Error: Snapshot comparison failed!"
    exit 1
fi'

# Check if the current directory is a git repository
if [ ! -d .git ]; then
    echo "Error: This is not a git repository."
    exit 1
fi

# Write the hook content to the pre-push file
echo "$HOOK_CONTENT" > .git/hooks/pre-push

# Make the hook executable
chmod +x .git/hooks/pre-push

echo "pre-push hook has been installed successfully!"


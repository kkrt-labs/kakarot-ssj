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

COMMIT_CONTENT='#!/bin/sh

# Run scarb fmt to format the project.
scarb fmt

# Check if any files were modified after running scarb fmt.
changed_files=$(git diff --name-only)

if [ -n "$changed_files" ]; then
    echo "The following files were reformatted. Please add them to your commit and try again:"
    echo "$changed_files"
    exit 1
fi

# Continue with the commit if no issues were found.
exit 0
'

# Check if the current directory is a git repository
if [ ! -d .git ]; then
    echo "Error: This is not a git repository."
    exit 1
fi

# Write the hook content to the pre-push file
echo "$COMMIT_CONTENT" > .git/hooks/pre-commit
echo "$HOOK_CONTENT" > .git/hooks/pre-push

# Make the hook executable
chmod +x .git/hooks/pre-commit
chmod +x .git/hooks/pre-push

echo "pre-commit hook has been installed successfully!"
echo "pre-push hook has been installed successfully!"


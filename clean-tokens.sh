#!/bin/bash

# Script to remove sensitive tokens and user information from git history
# This will rewrite the git history to remove any hardcoded tokens

echo "Cleaning sensitive information from git history..."

# Check if we're in a git repository
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo "Error: Not in a git repository"
    exit 1
fi

# Create a backup of the current branch
echo "Creating backup of current branch..."
git branch backup-$(date +%Y%m%d-%H%M%S)

# Remove sensitive patterns from git history
echo "Removing sensitive patterns from git history..."

# Use git filter-branch to rewrite history and remove sensitive data
git filter-branch --force --tree-filter '
    # Remove any files that might contain tokens
    find . -name "*.yaml" -o -name "*.yml" | while read file; do
        if grep -q "token:" "$file" || grep -q "sha256~" "$file"; then
            echo "Removing sensitive content from: $file"
            # Remove lines containing tokens
            sed -i.bak "/token:/d; /sha256~/d" "$file"
            rm -f "$file.bak"
        fi
    done
    
    # Remove any hardcoded user information
    find . -name "*.yaml" -o -name "*.yml" | while read file; do
        if grep -q "lbacciot" "$file"; then
            echo "Removing hardcoded user info from: $file"
            # Replace hardcoded user with placeholder
            sed -i.bak "s/lbacciot/YOUR-USERNAME/g" "$file"
            rm -f "$file.bak"
        fi
    done
' --prune-empty --tag-name-filter cat -- --all

echo "History cleaned. Sensitive information has been removed."
echo ""
echo "IMPORTANT: You need to force push to update the remote repository:"
echo "  git push --force-with-lease"
echo ""
echo "WARNING: This will rewrite the git history. Make sure all team members"
echo "are aware of this change and will need to re-clone the repository."

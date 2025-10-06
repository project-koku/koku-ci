#!/bin/bash

# Script to remove hardcoded URLs from git history
# This will rewrite the git history to replace URLs with placeholders

# URLs to replace
URLS_TO_REPLACE=(
    "https://api.stone-prd-rh01.pg1f.p1.openshiftapps.com:6443/"
    "https://api.crc-eph.r9lp.p1.openshiftapps.com:6443"
    "https://api.crcs02ue1.urby.p1.openshiftapps.com:6443"
    "https://api.crcp01ue1.o9m8.p1.openshiftapps.com:6443"
    "/Users/lucasbacciotti/development/konflux/konflux-cost-mgmt-dev.yaml"
)

# Replacements
REPLACEMENTS=(
    "https://YOUR-KONFLUX-CLUSTER:6443/"
    "https://YOUR-EPHEMERAL-CLUSTER:6443"
    "https://YOUR-STAGE-CLUSTER:6443"
    "https://YOUR-PROD-CLUSTER:6443"
    "/path/to/your/konflux-kubeconfig.yaml"
)

echo "Removing hardcoded URLs from git history..."

# Use git filter-branch to rewrite history
git filter-branch --force --tree-filter '
    for i in "${!URLS_TO_REPLACE[@]}"; do
        find . -type f -name "*.sh" -o -name "*.md" -o -name "*.example" | xargs sed -i.bak "s|${URLS_TO_REPLACE[$i]}|${REPLACEMENTS[$i]}|g"
        find . -name "*.bak" -delete
    done
' --prune-empty --tag-name-filter cat -- --all

echo "History rewritten. URLs have been replaced with placeholders."
echo "You may need to force push: git push --force-with-lease"

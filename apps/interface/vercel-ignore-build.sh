#!/bin/bash

# Navigate to repo root from apps/interface
cd ../..

# Check if there are changes in the interface app, sdk, packages, or shared dependencies
git diff HEAD^ HEAD --quiet apps/interface/ apps/sdk/ packages/ package.json pnpm-lock.yaml turbo.json

# Exit code 1 means changes were found (proceed with build)
# Exit code 0 means no changes (skip build)
if [ $? -eq 0 ]; then
  echo "🚫 No changes in interface, sdk, or packages - skipping build"
  exit 0
else
  echo "✅ Changes detected - proceeding with build"
  exit 1
fi

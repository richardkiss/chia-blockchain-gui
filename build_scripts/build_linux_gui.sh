#!/usr/bin/env bash
set -o errexit

echo "npm build"
npx lerna clean -y
npm ci
npm run build

# Remove unused packages to save space
rm -rf packages/api
rm -rf packages/api-react
rm -rf packages/core
rm -rf packages/icons
rm -rf packages/wallets

# Cleanup node_modules in gui
cd ./packages/gui/node_modules || exit 1
rm -rf electron/dist
rm -rf "@mui"
rm -rf typescript
rm -rf "@chia-network"

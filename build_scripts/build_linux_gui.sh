#!/usr/bin/env bash
set -o errexit

echo "npm build"
npx lerna clean -y
npm ci

# Function to normalize Python version to SemVer
# e.g., 2.5.7.dev0 -> 2.5.7-dev0
# e.g., 2.5.7rc1 -> 2.5.7-rc1
normalize_version() {
  echo "$1" | sed -E 's/([0-9])(rc|beta|alpha|dev)/\1-\2/g'
}

# Inject version if CHIA_INSTALLER_VERSION is set
if [ -n "$CHIA_INSTALLER_VERSION" ]; then
  echo "Setting version to $CHIA_INSTALLER_VERSION"
  cp package.json package.json.orig
  
  SEMVER_VERSION=$(normalize_version "$CHIA_INSTALLER_VERSION")
  echo "Normalized version to $SEMVER_VERSION"
  
  GUI_VERSION=$(jq -r .version package.json)
  jq --arg VER "$SEMVER_VERSION" --arg GUI_VER "$GUI_VERSION" '.version=$VER | .guiVersion=$GUI_VER' package.json >temp.json && mv temp.json package.json
fi

npm run build

if [ -f package.json.orig ]; then
  mv package.json.orig package.json
fi

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

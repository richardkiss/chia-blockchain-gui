#!/usr/bin/env bash

set -o errexit

if [ ! "$1" ]; then
  PLATFORM="amd64"
else
  PLATFORM="$1"
fi
export PLATFORM

if [ ! "$CHIA_INSTALLER_VERSION" ]; then
  echo "WARNING: No environment variable CHIA_INSTALLER_VERSION set. Using 0.0.0."
  CHIA_INSTALLER_VERSION="0.0.0"
fi
export CHIA_INSTALLER_VERSION

echo "Installing npm deps for build scripts"
cd build_scripts/npm_linux || exit 1
npm ci
NPM_PATH="$(pwd)/node_modules/.bin"
cd ../.. || exit 1

echo "Create dist/"
rm -rf dist
mkdir dist

echo "Create executables with pyinstaller"
SPEC_FILE=$(python -c 'import sys; from pathlib import Path; path = Path(sys.argv[1]); print(path.absolute().as_posix())' "build_scripts/pyinstaller.spec")
pyinstaller --log-level=INFO "$SPEC_FILE"

echo "Building pip and NPM license directory"
bash build_scripts/build_license_directory.sh

pip install jinjanator
CLI_DEB_BASE="chia-blockchain-cli_$CHIA_INSTALLER_VERSION-1_$PLATFORM"
mkdir -p "dist/$CLI_DEB_BASE/opt/chia"
mkdir -p "dist/$CLI_DEB_BASE/usr/bin"
mkdir -p "dist/$CLI_DEB_BASE/DEBIAN"
mkdir -p "dist/$CLI_DEB_BASE/etc/systemd/system"

format_deb_version_string() {
  version_str=$1
  echo "$version_str" | sed -E 's/([0-9])(rc|beta)/\1-\2/g; s/\.dev/-dev/g'
}

CHIA_DEB_CONTROL_VERSION=$(format_deb_version_string "$CHIA_INSTALLER_VERSION")
export CHIA_DEB_CONTROL_VERSION

j2 -o "dist/$CLI_DEB_BASE/DEBIAN/control" build_scripts/assets/deb/control.j2
cp build_scripts/assets/systemd/*.service "dist/$CLI_DEB_BASE/etc/systemd/system/"
cp -r dist/daemon/* "dist/$CLI_DEB_BASE/opt/chia/"

ln -s ../../opt/chia/chia "dist/$CLI_DEB_BASE/usr/bin/chia"
dpkg-deb --build --root-owner-group "dist/$CLI_DEB_BASE"

# Copy daemon to GUI
rm -rf packages/gui/daemon
cp -r dist/daemon packages/gui/daemon

# Build GUI Electron App
cd packages/gui || exit 1

cp package.json package.json.orig
jq --arg VER "$CHIA_INSTALLER_VERSION" '.version=$VER' package.json >temp.json && mv temp.json package.json

echo "Building Linux(deb) Electron app"
PRODUCT_NAME="chia"
CONFIG_PATH="../../build_scripts/electron-builder.json"

if [ "$PLATFORM" = "arm64" ]; then
  echo USE_SYSTEM_FPM=true "${NPM_PATH}/electron-builder" build --linux deb --arm64 \
    --config.extraMetadata.name=chia-blockchain \
    --config.productName="$PRODUCT_NAME" --config.linux.desktop.Name="Chia Blockchain" \
    --config.deb.packageName="chia-blockchain" \
    --config "$CONFIG_PATH"
  USE_SYSTEM_FPM=true "${NPM_PATH}/electron-builder" build --linux deb --arm64 \
    --config.extraMetadata.name=chia-blockchain \
    --config.productName="$PRODUCT_NAME" --config.linux.desktop.Name="Chia Blockchain" \
    --config.deb.packageName="chia-blockchain" \
    --config "$CONFIG_PATH"
  LAST_EXIT_CODE=$?
else
  echo "${NPM_PATH}/electron-builder" build --linux deb --x64 \
    --config.extraMetadata.name=chia-blockchain \
    --config.productName="$PRODUCT_NAME" --config.linux.desktop.Name="Chia Blockchain" \
    --config.deb.packageName="chia-blockchain" \
    --config "$CONFIG_PATH"
  "${NPM_PATH}/electron-builder" build --linux deb --x64 \
    --config.extraMetadata.name=chia-blockchain \
    --config.productName="$PRODUCT_NAME" --config.linux.desktop.Name="Chia Blockchain" \
    --config.deb.packageName="chia-blockchain" \
    --config "$CONFIG_PATH"
  LAST_EXIT_CODE=$?
fi

mv package.json.orig package.json

if [ "$LAST_EXIT_CODE" -ne 0 ]; then
  echo >&2 "electron-builder failed!"
  exit $LAST_EXIT_CODE
fi

GUI_DEB_NAME=chia-blockchain_${CHIA_INSTALLER_VERSION}_${PLATFORM}.deb
cd ../.. || exit 1

echo "Create final installer"
rm -rf final_installer
mkdir final_installer

mv "packages/gui/dist/${PRODUCT_NAME}-${CHIA_INSTALLER_VERSION}.deb" "final_installer/${GUI_DEB_NAME}"
mv "dist/${CLI_DEB_BASE}.deb" "final_installer/"

ls -l final_installer/

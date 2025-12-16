#!/usr/bin/env bash
set -o errexit

# PULL IN LICENSES USING NPM - LICENSE CHECKER
npm install -g license-checker

# We assume dependencies are available or we run npm ci
# npm ci

sum=$(license-checker --summary)
printf "%s\n" "$sum"

license_list=$(license-checker --json | jq -r '.[].licenseFile' | grep -v null)
IFS=$'\n' read -rd '' -a licenses_array <<<"$license_list"

mkdir -p licenses
for i in "${licenses_array[@]}"; do
  dirname="licenses/$(dirname "$i" | awk -F'/' '{print $NF}')"
  mkdir -p "$dirname"
  echo "$dirname"
  cp "$i" "$dirname"
done

# Move to dist/daemon
mkdir -p dist/daemon
mv licenses/ dist/daemon/licenses

# PULL IN THE LICENSES FROM PIP-LICENSE
pip install pip-licenses

# capture the output of the command in a variable
output=$(pip-licenses -l -f json | jq -r '.[].LicenseFile' | grep -v UNKNOWN)

# initialize an empty array
license_path_array=()

# read the output line by line into the array
while IFS= read -r line; do
  license_path_array+=("$line")
done <<<"$output"

# create a dir for each license and copy the license file over
for i in "${license_path_array[@]}"; do
  dirname="dist/daemon/licenses/$(dirname "$i" | awk -F'/' '{print $NF}')"
  echo "$dirname"
  mkdir -p "$dirname"
  cp "$i" "$dirname"
done

ls -lah dist/daemon

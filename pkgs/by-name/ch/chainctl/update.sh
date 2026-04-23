#!/usr/bin/env nix-shell
#!nix-shell -i bash -p curl jq common-updater-scripts
# shellcheck shell=bash
#
# Refresh pkgs/by-name/ch/chainctl/package.nix to the latest upstream release.
# Reads the current version from Chainguard's metadata endpoint, then defers
# to `update-source-version` for each per-platform fetchurl source exposed
# via passthru.sources.

set -euo pipefail

VERSION="$(curl -fsSL https://dl.enforce.dev/chainctl/latest/metadata.json | jq -r .version)"
echo "chainctl: latest upstream version is $VERSION"

# update-source-version bumps the top-level `version` on the first invocation;
# subsequent ones use --ignore-same-version so they only refresh the per-platform
# hash without complaining that the version is already up to date.
for platform in \
  x86_64-linux \
  aarch64-linux \
  x86_64-darwin \
  aarch64-darwin; do
  echo "chainctl: updating $platform"
  update-source-version chainctl "$VERSION" \
    --source-key="sources.${platform}" \
    --ignore-same-version
done

echo "chainctl: done"

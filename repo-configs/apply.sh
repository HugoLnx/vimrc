#!/usr/bin/env bash
# Copies this folder's gitignore/gitattributes templates into the current
# working directory as .gitignore/.gitattributes.
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

cp "$script_dir/gitignore" ./.gitignore
cp "$script_dir/gitattributes" ./.gitattributes

echo "Copied .gitignore and .gitattributes into $(pwd)"

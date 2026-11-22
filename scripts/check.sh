#!/usr/bin/env bash
set -euo pipefail

echo "=== Running Terraform Format Check ==="
terraform fmt -check -recursive

echo "=== Running Terraform Validation ==="
terraform validate -no-color

echo "=== Terraform checks passed successfully! ==="

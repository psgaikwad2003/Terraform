$ErrorActionPreference = "Stop"

Write-Host "=== Running Terraform Format Check ===" -ForegroundColor Cyan
terraform fmt -check -recursive

Write-Host "=== Running Terraform Validation ===" -ForegroundColor Cyan
terraform validate -no-color

Write-Host "=== Terraform checks passed successfully! ===" -ForegroundColor Green

#!/bin/bash

# Setup script for Power Tuning and other tools

echo "🚀 Setting up AWS Serverless CRUD Terraform project..."

# Make scripts executable
echo "✓ Making scripts executable..."
chmod +x scripts/*.sh
chmod +x scripts/*.py 2>/dev/null || true

# Create results directory
echo "✓ Creating results directory..."
mkdir -p tests/load/results

# Check for required tools
echo ""
echo "📋 Checking for required tools..."

MISSING_TOOLS=()

if ! command -v terraform &> /dev/null; then
    MISSING_TOOLS+=("terraform")
    echo "  ❌ terraform not found"
else
    TERRAFORM_VERSION=$(terraform version -json 2>/dev/null | jq -r '.terraform_version' 2>/dev/null || echo "unknown")
    echo "  ✓ terraform ($TERRAFORM_VERSION)"
fi

if ! command -v aws &> /dev/null; then
    MISSING_TOOLS+=("aws-cli")
    echo "  ❌ aws-cli not found"
else
    AWS_VERSION=$(aws --version 2>&1 | cut -d' ' -f1)
    echo "  ✓ aws-cli ($AWS_VERSION)"
fi

if ! command -v jq &> /dev/null; then
    echo "  ⚠️  jq not found (optional, needed for JSON parsing)"
else
    echo "  ✓ jq"
fi

if ! command -v python3 &> /dev/null; then
    MISSING_TOOLS+=("python3")
    echo "  ❌ python3 not found"
else
    PYTHON_VERSION=$(python3 --version 2>&1 | cut -d' ' -f2)
    echo "  ✓ python3 ($PYTHON_VERSION)"
fi

if ! command -v k6 &> /dev/null; then
    echo "  ⚠️  k6 not found (optional, needed for load testing)"
else
    K6_VERSION=$(k6 version 2>&1)
    echo "  ✓ k6 ($K6_VERSION)"
fi

echo ""

if [ ${#MISSING_TOOLS[@]} -gt 0 ]; then
    echo "❌ Missing required tools: ${MISSING_TOOLS[@]}"
    echo ""
    echo "Install instructions:"
    echo "  • Terraform: https://www.terraform.io/downloads.html"
    echo "  • AWS CLI: https://aws.amazon.com/cli/"
    echo "  • Python 3: https://www.python.org/downloads/"
    echo "  • jq (optional): brew install jq"
    echo "  • k6 (optional): https://k6.io/docs/getting-started/installation/"
    exit 1
fi

echo "✅ All required tools are installed!"
echo ""
echo "📚 Next steps:"
echo "  1. Configure AWS credentials:"
echo "     $ aws configure"
echo ""
echo "  2. Deploy the infrastructure:"
echo "     $ cd terraform && terraform apply"
echo ""
echo "  3. Run Power Tuning:"
echo "     $ ./scripts/run-power-tuning.sh"
echo ""
echo "  4. View results:"
echo "     $ ./scripts/run-power-tuning.sh --latest"
echo ""
echo "📖 For help, run:"
echo "  $ ./scripts/power-tuning-help.sh"
echo ""

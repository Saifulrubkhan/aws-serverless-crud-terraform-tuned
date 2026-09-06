#!/bin/bash

# Complete workflow demonstration
# Shows the full setup and testing process

set -e

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║     AWS Lambda Power Tuning - Complete Workflow Demo          ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# Configuration
DEMO_MODE="${1:-dry-run}"  # dry-run or full-run

if [[ "$DEMO_MODE" == "dry-run" ]]; then
    echo "📋 DRY-RUN MODE - Showing what would happen"
    echo "   (No actual deployments or AWS calls)"
    echo ""
    RUN_CMD="echo [WOULD RUN]"
else
    echo "🚀 FULL-RUN MODE - Executing all steps"
    echo "   (This will create AWS resources and incur costs)"
    echo ""
    read -p "Continue? (type 'yes' to confirm): " confirmation
    if [[ "$confirmation" != "yes" ]]; then
        echo "Cancelled."
        exit 1
    fi
    RUN_CMD=""
fi

# Step 1: Setup
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📋 Step 1: Setup & Verification"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Making scripts executable..."
$RUN_CMD chmod +x scripts/*.sh scripts/*.py

echo "Creating results directory..."
$RUN_CMD mkdir -p tests/load/results

echo "✓ Environment ready"
echo ""

# Step 2: Deploy Infrastructure
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🏗️  Step 2: Deploy Infrastructure with Terraform"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Resources to be created:"
echo "  • Lambda function (Python 3.13, with inline code)"
echo "  • IAM role with DynamoDB & CloudWatch permissions"
echo "  • API Gateway REST API (DynamoDBOperations)"
echo "  • DynamoDB table (lambda-apigateway, on-demand)"
echo "  • Lambda Power Tuning Step Functions state machine"
echo ""
echo "Deployment commands:"
echo "  cd terraform"
echo "  terraform init"
echo "  terraform plan"
echo "  terraform apply"
echo ""

if [[ "$DEMO_MODE" != "dry-run" ]]; then
    cd terraform
    echo "Running: terraform init"
    terraform init
    
    echo ""
    echo "Running: terraform plan"
    terraform plan
    
    echo ""
    read -p "Apply these changes? (yes/no): " apply_confirm
    if [[ "$apply_confirm" == "yes" ]]; then
        echo "Running: terraform apply"
        terraform apply
        
        # Save outputs
        API_URL=$(terraform output -raw api_invoke_url)
        LAMBDA_ARN=$(terraform output -raw lambda_function_arn)
        
        echo ""
        echo "✓ Infrastructure deployed!"
        echo "  API URL: $API_URL"
        echo "  Lambda ARN: $LAMBDA_ARN"
    else
        echo "Skipping deployment"
        exit 1
    fi
    
    cd ..
else
    echo "[WOULD RUN] terraform init && terraform plan && terraform apply"
    API_URL="https://xxxxx.execute-api.us-west-2.amazonaws.com/v1/dynamodbmanager"
    LAMBDA_ARN="arn:aws:lambda:us-west-2:123456789012:function:crud-api-function"
fi

echo ""

# Step 3: Smoke Test
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Step 3: Smoke Test - Verify API Works"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Testing POST /dynamodbmanager:"
echo ""

CURL_CMD="curl -X POST \"$API_URL\" -H 'Content-Type: application/json' -d '{\"id\":\"demo-item\",\"name\":\"Demo Item\",\"description\":\"Created via demo script\"}'"

echo "Command: $CURL_CMD"
echo ""

if [[ "$DEMO_MODE" != "dry-run" ]]; then
    response=$($CURL_CMD)
    echo "Response:"
    echo "$response" | jq '.' 2>/dev/null || echo "$response"
    echo "✓ API is working!"
else
    echo "[WOULD RUN] $CURL_CMD"
    echo ""
    echo "[RESPONSE]"
    echo "{\"statusCode\":201,\"body\":\"{\\\"id\\\":\\\"demo-item\\\",...}\"}"
fi

echo ""

# Step 4: Power Tuning - Light Test
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "⚡ Step 4a: Run Light Power Tuning Test (Fast)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Running Power Tuning with light profile:"
echo "  • Memory levels: 128, 256, 512, 1024 MB"
echo "  • Invocations per level: 10"
echo "  • Total invocations: ~40"
echo "  • Estimated time: 2-3 minutes"
echo "  • Estimated cost: ~$0.01"
echo ""

if [[ "$DEMO_MODE" != "dry-run" ]]; then
    echo "Starting: ./scripts/run-power-tuning.sh light"
    ./scripts/run-power-tuning.sh light
else
    echo "[WOULD RUN] ./scripts/run-power-tuning.sh light"
fi

echo ""

# Step 5: Get Results
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 Step 4b: Fetch & Display Results"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Getting visualization URL:"
echo ""

if [[ "$DEMO_MODE" != "dry-run" ]]; then
    echo "Running: ./scripts/run-power-tuning.sh --latest"
    ./scripts/run-power-tuning.sh --latest
else
    echo "[WOULD RUN] ./scripts/run-power-tuning.sh --latest"
    echo ""
    echo "[OUTPUT]"
    echo "📊 Visualization URL (example):"
    echo "https://lambda-power-tuning.show/?id=xxxxx"
fi

echo ""

# Step 6: Analyze Results
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📈 Step 5: Analyze Results Locally"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Analyzing Power Tuning results:"
echo ""

if [[ "$DEMO_MODE" != "dry-run" ]]; then
    if ls tests/load/results/results-*.json 1> /dev/null 2>&1; then
        python3 scripts/analyze-power-tuning.py tests/load/results/results-*.json
    else
        echo "⚠️  No results found yet (test may still be running)"
    fi
else
    echo "[WOULD RUN] python3 scripts/analyze-power-tuning.py tests/load/results/results-*.json"
    echo ""
    echo "[OUTPUT - Example Results]"
    echo "Memory      Duration    Cost/1M"
    echo "128 MB      120ms       \$0.21"
    echo "256 MB      65ms        \$0.22"
    echo "512 MB      35ms        \$0.23"
    echo "1024 MB     20ms        \$0.26"
fi

echo ""

# Step 7: Optimize
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🎯 Step 6: Optimize Lambda Memory"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Based on results, update Lambda memory:"
echo ""
echo "Command: cd terraform && terraform apply -var=\"lambda_memory_size=512\""
echo ""
echo "(In this example, 512 MB was optimal)"
echo ""

if [[ "$DEMO_MODE" != "dry-run" ]]; then
    read -p "Update Lambda memory to 512 MB? (yes/no): " memory_confirm
    if [[ "$memory_confirm" == "yes" ]]; then
        cd terraform
        terraform apply -var="lambda_memory_size=512"
        cd ..
        echo "✓ Lambda memory updated to 512 MB"
    fi
fi

echo ""

# Step 8: Load Test
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔥 Step 7: k6 Load Test (Optional)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Run k6 load test against the optimized deployment:"
echo ""

if command -v k6 &> /dev/null; then
    echo "k6 is installed. Running load test..."
    echo ""
    if [[ "$DEMO_MODE" != "dry-run" ]]; then
        API_URL=$(cd terraform && terraform output -raw api_invoke_url && cd ..)
        k6 run tests/load/k6-script.js --env API_URL=$API_URL
    else
        echo "[WOULD RUN] k6 run tests/load/k6-script.js --env API_URL=$API_URL"
    fi
else
    echo "k6 not installed. To install:"
    echo "  brew install k6           (macOS)"
    echo "  apt-get install k6        (Linux)"
    echo "  choco install k6          (Windows)"
    echo ""
    echo "Then run: k6 run tests/load/k6-script.js --env API_URL=$API_URL"
fi

echo ""

# Final Summary
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Workflow Complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📊 Results Saved To:"
echo "  tests/load/results/"
echo ""
echo "🚀 Next Steps:"
echo "  1. Review Power Tuning visualization graph"
echo "  2. Update lambda_memory_size based on results"
echo "  3. Re-run Power Tuning to verify improvement"
echo "  4. Run k6 load test for comprehensive analysis"
echo "  5. Update README.md with tuning results"
echo ""
echo "💰 Cleanup When Done:"
echo "  cd terraform && terraform destroy"
echo ""
echo "📖 For More Help:"
echo "  • ./scripts/power-tuning-help.sh"
echo "  • README.md"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

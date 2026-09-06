#!/bin/bash

# Lambda Power Tuning Runner Script
# Runs AWS Lambda Power Tuning with configurable load profiles
# Usage: ./scripts/run-power-tuning.sh [light|medium|heavy] [--report]
#        ./scripts/run-power-tuning.sh --latest

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

if [[ "${1:-}" == "--latest" ]]; then
    RESULTS_DIR="tests/load/results"
    LATEST_EXECUTION=$(ls -t "$RESULTS_DIR"/execution-*.json 2>/dev/null | head -1)

    if [[ -z "$LATEST_EXECUTION" ]]; then
        echo "❌ No Power Tuning executions found"
        echo "Run: ./scripts/run-power-tuning.sh medium"
        exit 1
    fi

    echo "📋 Latest execution: $(basename "$LATEST_EXECUTION")"
    EXEC_ARN=$(jq -r '.executionArn' "$LATEST_EXECUTION")
    REGION=$(jq -r '.region' "$LATEST_EXECUTION")
    echo "⏳ Fetching execution results..."
    OUTPUT=$(aws stepfunctions describe-execution \
        --execution-arn "$EXEC_ARN" \
        --region "$REGION" \
        --query 'output' \
        --output text)

    if [[ -z "$OUTPUT" ]] || [[ "$OUTPUT" == "null" ]]; then
        echo "⚠️  Execution may still be running or output not available"
        echo "Check status: aws stepfunctions describe-execution --execution-arn $EXEC_ARN"
        exit 1
    fi

    VIZ_URL=$(echo "$OUTPUT" | jq -r '.visualization' 2>/dev/null || echo "")
    if [[ -z "$VIZ_URL" ]] || [[ "$VIZ_URL" == "null" ]]; then
        echo "❌ Visualization URL not found in results"
        echo "The execution may not be complete yet"
        exit 1
    fi

    echo ""
    echo "📊 Lambda Power Tuning Visualization"
    echo ""
    echo "$VIZ_URL"

    if command -v xdg-open &> /dev/null; then
        read -p "🌐 Open in browser? (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then xdg-open "$VIZ_URL"; fi
    elif command -v open &> /dev/null; then
        read -p "🌐 Open in browser? (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then open "$VIZ_URL"; fi
    fi

    TIMESTAMP=$(basename "$LATEST_EXECUTION" .json | sed 's/execution-//')
    echo "$VIZ_URL" > "$RESULTS_DIR/visualization-url-${TIMESTAMP}.txt"
    echo "✅ URL saved to: $RESULTS_DIR/visualization-url-${TIMESTAMP}.txt"
    exit 0
fi

# Load configuration
LOAD_PROFILE="${1:-medium}"
REPORT=false
if [[ "${2:-}" == "--report" ]]; then
    REPORT=true
fi
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
RESULTS_DIR="tests/load/results"
mkdir -p "$RESULTS_DIR"

# Get Lambda ARN and Power Tuning ARN from Terraform
echo -e "${BLUE}📋 Fetching AWS resources...${NC}"
cd terraform
LAMBDA_ARN=$(terraform output -raw lambda_function_arn 2>/dev/null)
POWER_TUNING_ARN=$(terraform output -raw power_tuning_state_machine_arn 2>/dev/null)
AWS_REGION=$(terraform console -no-color 2>/dev/null <<'EOF'
var.aws_region
EOF
)
AWS_REGION=${AWS_REGION//\"/}
LAMBDA_NAME=$(terraform output -raw lambda_function_name 2>/dev/null)
cd ..

if [[ -z "$AWS_REGION" ]] || [[ "$AWS_REGION" == "null" ]]; then
    AWS_REGION="us-east-1"
fi

if [[ -z "$LAMBDA_ARN" ]] || [[ -z "$POWER_TUNING_ARN" ]]; then
    echo -e "${RED}❌ Error: Could not retrieve Lambda ARN or Power Tuning ARN${NC}"
    echo "Make sure Terraform has been applied: terraform apply"
    exit 1
fi

echo -e "${GREEN}✓ Lambda ARN: $LAMBDA_ARN${NC}"
echo -e "${GREEN}✓ Power Tuning ARN: $POWER_TUNING_ARN${NC}"

# Load profile configurations
case $LOAD_PROFILE in
    light)
        NUM_INVOCATIONS=10
        MEMORY_VALUES="128,256,512,1024"
        TEST_DESCRIPTION="Light Load Test (10 invocations per memory level)"
        ;;
    medium)
        NUM_INVOCATIONS=50
        MEMORY_VALUES="128,256,512,1024,1536,3008"
        TEST_DESCRIPTION="Medium Load Test (50 invocations per memory level)"
        ;;
    heavy)
        NUM_INVOCATIONS=100
        MEMORY_VALUES="128,256,512,1024,1536,3008,5120,7680,10240"
        TEST_DESCRIPTION="Heavy Load Test (100 invocations per memory level)"
        ;;
    *)
        echo -e "${RED}❌ Unknown load profile: $LOAD_PROFILE${NC}"
        echo "Valid options: light, medium, heavy"
        exit 1
        ;;
esac

echo -e "${BLUE}⚙️  Configuration:${NC}"
echo "  Profile: $LOAD_PROFILE"
echo "  Description: $TEST_DESCRIPTION"
echo "  Memory levels: $MEMORY_VALUES"
echo "  Invocations per level: $NUM_INVOCATIONS"
echo "  Total invocations: $(echo $MEMORY_VALUES | tr ',' '\n' | wc -l) × $NUM_INVOCATIONS"

# Create test payload
PAYLOAD=$(cat <<EOF
{
  "lambdaARN": "$LAMBDA_ARN",
  "powerValues": [$MEMORY_VALUES],
  "num": $NUM_INVOCATIONS,
  "payload": {
    "httpMethod": "POST",
    "body": "{\\"id\\":\\"power-tuning-test\\",\\"name\\":\\"Lambda Power Tuning Test\\",\\"timestamp\\":\\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\\"}"
  },
  "parallelInvocation": true,
  "strategy": "balanced"
}
EOF
)

echo -e "${BLUE}🚀 Starting Power Tuning execution...${NC}"

# Start Step Functions execution
set +e
EXECUTION_RESPONSE=$(aws stepfunctions start-execution \
    --state-machine-arn "$POWER_TUNING_ARN" \
    --name "power-tuning-${LOAD_PROFILE}-${TIMESTAMP}" \
    --input "$PAYLOAD" \
    --region "$AWS_REGION" 2>&1)
START_STATUS=$?
set -e

if command -v jq &> /dev/null; then
    EXECUTION_ARN=$(echo "$EXECUTION_RESPONSE" | jq -r '.executionArn // empty' 2>/dev/null)
else
    EXECUTION_ARN=$(echo "$EXECUTION_RESPONSE" | sed -nE 's/.*"executionArn"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/p')
fi
EXECUTION_NAME=$(echo "$EXECUTION_ARN" | rev | cut -d':' -f1 | rev)

if [[ $START_STATUS -ne 0 ]] || [[ -z "$EXECUTION_ARN" ]]; then
    echo -e "${RED}❌ Failed to start execution${NC}"
    echo "$EXECUTION_RESPONSE"
    exit 1
fi

echo -e "${GREEN}✓ Execution started${NC}"
echo -e "${YELLOW}Execution Name: $EXECUTION_NAME${NC}"
echo -e "${YELLOW}Execution ARN: $EXECUTION_ARN${NC}"

# Save execution details
cat > "$RESULTS_DIR/execution-${TIMESTAMP}.json" <<EOF
{
  "executionArn": "$EXECUTION_ARN",
  "executionName": "$EXECUTION_NAME",
  "loadProfile": "$LOAD_PROFILE",
  "timestamp": "$TIMESTAMP",
  "lambdaArn": "$LAMBDA_ARN",
  "lambdaName": "$LAMBDA_NAME",
  "region": "$AWS_REGION",
  "memoryValues": [$MEMORY_VALUES],
  "invocationsPerLevel": $NUM_INVOCATIONS
}
EOF

echo -e "${BLUE}📊 Monitoring execution...${NC}"

# Poll for execution status
MAX_WAIT=1800  # 30 minutes
POLL_INTERVAL=10
ELAPSED=0
LAST_STATUS=""

while [ $ELAPSED -lt $MAX_WAIT ]; do
    STATUS=$(aws stepfunctions describe-execution \
        --execution-arn "$EXECUTION_ARN" \
        --region "$AWS_REGION" \
        --query 'status' \
        --output text)
    
    if [[ "$STATUS" != "$LAST_STATUS" ]]; then
        echo -e "${YELLOW}[$(date +'%H:%M:%S')] Status: $STATUS${NC}"
        LAST_STATUS="$STATUS"
    fi
    
    if [[ "$STATUS" == "SUCCEEDED" ]]; then
        echo -e "${GREEN}✓ Execution completed successfully!${NC}"
        break
    elif [[ "$STATUS" == "FAILED" ]] || [[ "$STATUS" == "TIMED_OUT" ]]; then
        echo -e "${RED}❌ Execution failed with status: $STATUS${NC}"
        exit 1
    fi
    
    sleep $POLL_INTERVAL
    ELAPSED=$((ELAPSED + POLL_INTERVAL))
done

if [ $ELAPSED -ge $MAX_WAIT ]; then
    echo -e "${YELLOW}⏱️  Execution still running (timeout after 30 min)${NC}"
    echo "Check status in AWS Console or with:"
    echo "aws stepfunctions describe-execution --execution-arn $EXECUTION_ARN"
fi

# Fetch execution results
echo -e "${BLUE}📥 Fetching results...${NC}"

EXECUTION_OUTPUT=$(aws stepfunctions describe-execution \
    --execution-arn "$EXECUTION_ARN" \
    --region "$AWS_REGION" \
    --query 'output' \
    --output text)

# Save full output
echo "$EXECUTION_OUTPUT" > "$RESULTS_DIR/output-${TIMESTAMP}.json"

# Try to parse and display results
if command -v jq &> /dev/null; then
    echo "$EXECUTION_OUTPUT" | jq '.' > "$RESULTS_DIR/results-${TIMESTAMP}.json" 2>/dev/null || true
    
    # Extract visualization URL
    VIZ_URL=$(echo "$EXECUTION_OUTPUT" | jq -r '.results.stateMachine.visualization // .visualization' 2>/dev/null || echo "")
    if [[ ! -z "$VIZ_URL" ]] && [[ "$VIZ_URL" != "null" ]]; then
        echo -e "${GREEN}✓ Visualization URL:${NC}"
        echo -e "${BLUE}$VIZ_URL${NC}"
        echo ""
        echo "Open this URL in your browser to see the performance graph"
        
        # Save URL to file
        echo "$VIZ_URL" > "$RESULTS_DIR/visualization-url-${TIMESTAMP}.txt"
    fi
    
    # Extract stats
    STATS=$(echo "$EXECUTION_OUTPUT" | jq '.results.stats // .stats' 2>/dev/null || echo "")
    if [[ ! -z "$STATS" ]] && [[ "$STATS" != "null" ]]; then
        echo -e "${GREEN}✓ Summary Statistics:${NC}"
        echo "$STATS" | jq '.'
    fi
else
    echo -e "${YELLOW}⚠️  jq not installed, saving raw output${NC}"
    echo "$EXECUTION_OUTPUT" > "$RESULTS_DIR/results-${TIMESTAMP}.json"
fi

echo -e "${GREEN}✅ Results saved to: $RESULTS_DIR${NC}"
echo ""
echo "Files generated:"
echo "  - execution-${TIMESTAMP}.json  (Execution metadata)"
echo "  - results-${TIMESTAMP}.json    (Full results)"
echo "  - output-${TIMESTAMP}.json     (Raw output)"
if [[ ! -z "$VIZ_URL" ]] && [[ "$VIZ_URL" != "null" ]]; then
    echo "  - visualization-url-${TIMESTAMP}.txt (Graph URL)"
fi

if [[ "$REPORT" == true ]] && [[ -f "$RESULTS_DIR/results-${TIMESTAMP}.json" ]]; then
    echo ""
    echo -e "${BLUE}📈 Analyzing this run...${NC}"
    python3 scripts/analyze-power-tuning.py "$RESULTS_DIR/results-${TIMESTAMP}.json"
fi

echo ""
echo -e "${BLUE}💡 Next steps:${NC}"
echo "  1. Open the visualization URL in your browser"
echo "  2. Review the cost/performance trade-off"
echo "  3. Update Lambda memory: terraform apply -var=\"lambda_memory_size=XXX\""
echo "  4. Re-deploy and re-test to verify improvement"

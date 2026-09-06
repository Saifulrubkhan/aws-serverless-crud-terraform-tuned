#!/bin/bash

# Lambda Power Tuning - Quick Reference
# Print help and examples

cat << 'EOF'

╔═══════════════════════════════════════════════════════════════════════════╗
║          AWS Lambda Power Tuning - Quick Reference Guide                 ║
╚═══════════════════════════════════════════════════════════════════════════╝

📚 DOCUMENTATION
  Full guide:      README.md
  Terraform:       terraform/power-tuning.tf
  Scripts:         scripts/run-power-tuning.sh
                   scripts/analyze-power-tuning.py

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

🚀 QUICK START (3 Steps)

  1️⃣  Deploy Infrastructure
      $ cd terraform
      $ terraform apply

    2️⃣  Run Power Tuning Test
      $ ./scripts/run-power-tuning.sh medium --report
      (Prints the analysis and visualization URL)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📊 LOAD PROFILES

  Light   (Fast):    ./scripts/run-power-tuning.sh light
  Medium  (Normal):  ./scripts/run-power-tuning.sh medium   ← Recommended
  Heavy   (Thorough): ./scripts/run-power-tuning.sh heavy

  Time to complete:  2-3 min (light) → 5-10 min (medium) → 15-30 min (heavy)
  AWS cost:          ~$0.01 (light) → $0.05 (medium) → $0.15 (heavy)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

🔍 VIEW RESULTS

  Get Latest Visualization URL:
    $ ./scripts/run-power-tuning.sh --latest

  Analyze Results Locally:
    $ python3 scripts/analyze-power-tuning.py tests/load/results/results-*.json

  Compare Multiple Runs:
    $ python3 scripts/analyze-power-tuning.py \
      tests/load/results/results-before.json \
      tests/load/results/results-after.json \
      --compare --graph

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

⚙️  OPTIMIZE & TEST

  1. Identify optimal memory from Power Tuning graph
  2. Update Lambda:
     $ terraform apply -var="lambda_memory_size=512"  # Example: 512 MB

  3. Re-test to verify improvement:
     $ ./scripts/run-power-tuning.sh medium

  4. Run k6 load test:
     $ k6 run tests/load/k6-script.js --env API_URL=$API_URL

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📁 RESULTS DIRECTORY

  All results saved to: tests/load/results/

  Files created per run:
    execution-TIMESTAMP.json   ← Execution metadata
    results-TIMESTAMP.json     ← Full results
    output-TIMESTAMP.json      ← Raw output
    visualization-url-TIMESTAMP.txt ← Visualization URL

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

💡 UNDERSTANDING THE GRAPHS

  4 graphs generated:
    1. Duration vs Memory          ← Shows latency improvement
    2. Cost per 1M Invocations     ← KEY METRIC (find the lowest point)
    3. Cost per Invocation         ← Raw cost
    4. Efficiency (ms/$)           ← Speed per dollar

  Optimal setting: Usually where "Cost per 1M" is lowest

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

🛠️  TROUBLESHOOTING

  Scripts not executable?
    chmod +x scripts/*.sh scripts/*.py

  Power Tuning deployment fails?
    • Check AWS permissions (IAM, Lambda, Step Functions)
    • Update semantic_version in terraform/power-tuning.tf

  No visualization URL?
    • Execution may still be running
    • Wait a few minutes and retry: ./scripts/run-power-tuning.sh --latest

  Need jq or matplotlib?
    jq:         brew install jq  (or: apt-get install jq)
    matplotlib: pip install matplotlib numpy

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📚 EXAMPLES

  # Basic test
  ./scripts/run-power-tuning.sh

  # Fast test
  ./scripts/run-power-tuning.sh light

  # Comprehensive test with 9 memory levels
  ./scripts/run-power-tuning.sh heavy

  # View latest results
  ./scripts/run-power-tuning.sh --latest

  # Analyze all results with graph
  python3 scripts/analyze-power-tuning.py \
    tests/load/results/results-*.json \
    --graph --output tests/load/results/comparison.png

  # Update Lambda to 512 MB based on results
  terraform apply -var="lambda_memory_size=512"

  # Run k6 load test after optimization
  export API_URL=$(terraform output -raw api_invoke_url)
  k6 run tests/load/k6-script.js --env API_URL=$API_URL

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

✅ EXPECTED RESULTS

  Typical optimization shows:
    • Cost reduction: 20-50% lower per 1M invocations
    • Latency: 50-70% improvement vs 128 MB baseline
    • Sweet spot: Usually 256-1024 MB for API workloads

  Example improvement:
    Before: 128 MB  → $0.21 per 1M invocations, 120ms latency
    After:  512 MB  → $0.23 per 1M invocations, 35ms latency
    Trade-off: +$0.02 cost for 70% latency improvement

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

❓ NEED HELP?

  For more details, see: README.md

  AWS Resources:
    • Lambda Power Tuning: https://github.com/alexcasalboni/aws-lambda-power-tuning
    • Lambda Pricing:      https://aws.amazon.com/lambda/pricing/
    • Lambda Best Practices: https://docs.aws.amazon.com/lambda/latest/dg/best-practices.html

╚═══════════════════════════════════════════════════════════════════════════╝

EOF

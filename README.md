# Serverless CRUD API — Terraform, API Gateway & Lambda with DynamoDB

A production-shaped serverless microservice on AWS: **API Gateway → Lambda → DynamoDB**.

Everything is deployed with Terraform with the Lambda function code defined inline for simplicity.

---

## API Overview

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/dynamodbmanager` | POST | Main CRUD operations endpoint |
| **API Name** | — | `DynamoDBOperations` |
| **DynamoDB Table** | — | `lambda-apigateway` |
| **Partition Key** | — | `id` (string) |

---

## TL;DR

<!-- Fill these in from your own runs. Do not copy numbers you have not measured. -->

| Metric | Value |
|---|---|
| Lambda memory | 512 MB (tuned via Power Tuning) |
| Lambda timeout | 10 seconds (default) |
| DynamoDB billing | PAY_PER_REQUEST (on-demand) |
| API Gateway type | REST (Regional) |

---

## Architecture

![Architecture diagram](https://github.com/user-attachments/assets/b143ef8a-0858-48f6-aecd-2541342e17a2)

**Components**

| Component | Details |
|---|---|
| **API Gateway** | REST API `DynamoDBOperations` with `/dynamodbmanager` resource |
| **Lambda** | Python 3.13 function with inline CRUD logic (defined in `terraform/lambda.tf`) |
| **DynamoDB** | Single-table design with partition key `id` (string) |
| **IAM Role** | Custom role with DynamoDB and CloudWatch Logs permissions |

**Why these services**

| Choice | Reason |
|---|---|
| **Lambda** | Serverless, spiky traffic, no idle cost |
| **DynamoDB** | Single-key access pattern, fully managed, on-demand billing |
| **API Gateway** | Simple REST integration with Lambda proxy |
| **On-demand DynamoDB** | Unpredictable load during development and testing |

---

## Repository layout

```
.
├── terraform/
│   ├── main.tf              # Provider, backend, locals
│   ├── lambda.tf            # Function with inline Python code, IAM role
│   ├── apigateway.tf        # REST API, resources, methods, deployment
│   ├── dynamodb.tf          # Table: lambda-apigateway
│   ├── variables.tf         # Configuration variables
│   └── outputs.tf           # API invoke URL, Lambda ARN, table name
├── src/
│   ├── handler.py           # Original CRUD logic (reference)
│   └── requirements.txt      # Python dependencies
├── tests/load/
│   └── k6-script.js         # Load testing script
├── .github/workflows/
│   └── cd.yml               # Terraform CI/CD pipeline
└── README.md
```

---

## Prerequisites

- AWS account with programmatic access
- Terraform >= 1.6
- Python 3.13 (for local testing)
- k6 (optional, for load testing)
- AWS CLI configured

**Quick setup:**
```bash
./scripts/setup.sh  # Checks all dependencies
```

---

## Deploy

```bash
git clone https://github.com/<your-username>/<repo-name>.git
cd <repo-name>/terraform

# Initialize Terraform
terraform init

# Plan and review changes
terraform plan

# Apply infrastructure
terraform apply
```

Get the API invoke URL:

```bash
export API_URL=$(terraform output -raw api_invoke_url)
echo $API_URL
```

---

## Testing

### Smoke Test (Quick Manual Test)

Test the POST endpoint:

```bash
curl -X POST "$API_URL/dynamodbmanager" \
  -H 'Content-Type: application/json' \
  -d '{"id":"1","name":"test-item","description":"A test item"}'
```

Expected response (201 Created):
```json
{
  "id": "1",
  "name": "test-item",
  "description": "A test item"
}
```

### Load Testing with k6

k6 is a modern load testing tool written in Go. It's lightweight and scriptable.

**Install k6:**
```bash
# macOS
brew install k6

# Linux
sudo apt-get install k6

# Windows
choco install k6
```

**Run load test:**
```bash
# Basic run (ramp-up → steady state → ramp-down)
k6 run tests/load/k6-script.js --env API_URL=$API_URL

# Export results for comparison
k6 run tests/load/k6-script.js --env API_URL=$API_URL \
  --summary-export tests/load/results/before.json

# Generate HTML report
K6_WEB_DASHBOARD=true k6 run tests/load/k6-script.js --env API_URL=$API_URL
```

**Load test parameters (k6-script.js):**
- Ramp-up: 30 seconds to 20 virtual users
- Steady state: 4 minutes at 20 users
- Ramp-down: 30 seconds to 0 users
- Success threshold: p(95) latency < 1000ms, error rate < 1%

### Load Test Results

| Run | VUs | Requests | Throughput | Avg | p95 | p99 | Errors |
|---|---|---|---|---|---|---|---|
| Load Test (512 MB) | `20` | `5029` | `16.7`/s | `77.4` ms | `85.1` ms | `95.4` ms | `0.0`% |

**Reading the results**

- The early p99 spike is cold starts. It settles once containers are warm.
- Watch `ConcurrentExecutions` against your account concurrency limit — that's the
  first ceiling you'll hit, before DynamoDB becomes a problem.
- p95 matters more than average. Averages hide the requests that make users leave.

### Lambda Power Tuning Results

| Metric | Benchmark Output |
|---|---|
| **Optimal Memory** | **512 MB** |
| **Avg Duration** | `5.33` ms |
| **Cost per Invocation** | `$0.0000000504` (`$0.0504` / 1M) |
| **Tuning Execution Cost** | `$0.0006` |
| **Interactive Graph** | [📊 View Power Tuning Visualization Graph](https://lambda-power-tuning.show/#gAAAAQACAAQABsAL;wcrvQeF6LkFmrapAnTa4QP7UnEASg6RA;Gs2LM2N3WDNjd1gzSYv8M4pZIjSt9540) |

---

### Lambda Power Tuning

Optimize your Lambda function for cost and performance using AWS Lambda Power Tuning.

**Quick start:**
```bash
# Deploy Power Tuning infrastructure
terraform apply

# Run a medium-load tuning test and analyze that run
./scripts/run-power-tuning.sh medium --report

# View the latest result graph later
./scripts/run-power-tuning.sh --latest
```

**Load profiles:**
- `light` - 10 invocations, 4 memory levels (2-3 min, ~$0.01)
- `medium` - 50 invocations, 6 memory levels (5-10 min, ~$0.05) **← Recommended**
- `heavy` - 100 invocations, 9 memory levels (15-30 min, ~$0.15)

**Typical workflow:**
1. Run Power Tuning to get performance graph
2. Identify optimal memory (usually where cost per 1M is lowest)
3. Update Lambda: `terraform apply -var="lambda_memory_size=512"`
4. Re-test to verify improvement

📖 **Full guide**: See the [Power tuning](#lambda-power-tuning) section above.

### Unit Testing

For local testing of the Lambda handler (before deployment):

```bash
cd src/
pip install -r requirements.txt
# Add unit tests as needed
```

---

## Cleanup

Tear down all AWS resources when done — this is important for avoiding unexpected bills:

```bash
terraform destroy
```

Confirm when prompted to delete all resources.

---

## CI/CD

The `.github/workflows/cd.yml` workflow (if configured):

1. Triggers on merge to `main`
2. Runs `terraform apply`
3. Smoke tests the deployed endpoint
4. Uses GitHub OIDC for short-lived AWS credentials

---

## Lambda Function

The Lambda function is defined **inline** in `terraform/lambda.tf` using a `locals` block with Python code.

**Current CRUD operations:**

```python
POST /dynamodbmanager
├── List items        (GET with no id)
├── Create item       (POST with body)
├── Read item         (GET with id)
├── Update item       (PUT with id)
└── Delete item       (DELETE with id)
```

To modify the function:
1. Edit the `lambda_code` local in `terraform/lambda.tf`
2. Run `terraform apply`

---

## Configuration

All settings are in `terraform/variables.tf`:

| Variable | Default | Description |
|----------|---------|-------------|
| `project_name` | `crud-api` | Resource name prefix |
| `aws_region` | `us-west-2` | AWS region |
| `lambda_memory_size` | `128` MB | Function memory |
| `lambda_timeout` | `10` seconds | Function timeout |
| `dynamodb_billing_mode` | `PAY_PER_REQUEST` | On-demand or provisioned |
| `api_stage_name` | `v1` | API deployment stage |

Override defaults:

```bash
terraform apply -var="aws_region=us-east-1" -var="lambda_memory_size=256"
```

---

## Outputs

After deployment, Terraform outputs:

```bash
terraform output
```

| Output | Description |
|--------|-------------|
| `api_invoke_url` | Full URL to invoke the API |
| `lambda_function_name` | Name of the Lambda function |
| `lambda_function_arn` | ARN for Lambda Power Tuning |
| `dynamodb_table_name` | DynamoDB table name |
| `power_tuning_state_machine_arn` | ARN of Power Tuning Step Functions state machine |
| `power_tuning_console_url` | Direct link to Power Tuning in AWS Console |

---

## Troubleshooting

**"Module not found" errors in Lambda**
- Ensure `requirements.txt` dependencies are bundled
- Lambda runtime must match: Python 3.13

**"User is not authorized to perform: dynamodb:PutItem"**
- Check IAM role permissions in `lambda.tf`
- Verify DynamoDB table exists

**"API returns 502 Bad Gateway"**
- Check Lambda logs: `aws logs tail /aws/lambda/crud-api-function --follow`
- Verify Lambda timeout is sufficient (default: 10s)

**Smoke test fails with 404**
- Confirm API_URL is set: `echo $API_URL`
- Check API Gateway deployment: `terraform output api_invoke_url`

---

## Cost Estimates

Using AWS pricing calculator (rough estimates):

- **Lambda**: $0.20/1M invocations (128 MB)
- **DynamoDB**: ~$1.25/1M write units (on-demand)
- **API Gateway**: $3.50 per million requests
- **CloudWatch Logs**: Minimal with 14-day retention

Total monthly (1M API calls): ~$5-10 depending on item sizes

---

## Observability

- **Structured JSON logs** with a request ID, so CloudWatch Logs Insights is actually
  usable

Example Logs Insights query — slowest 20 requests:

```
fields @timestamp, requestId, durationMs, path
| filter durationMs > 500
| sort durationMs desc
| limit 20
```

---

## Cost analysis

Assumptions: `1,000,000` requests/month, average duration `77.4` ms at `512` MB, us-east-1
pricing, `1` KB average item size.

| Component | Monthly cost | Notes |
|---|---|---|
| Lambda | `$0.00` | 1M free requests + 400,000 GB-s free tier |
| API Gateway REST | `$3.50` | $3.50 per million calls |
| DynamoDB on-demand | `$1.25` | Write units dominate |
| CloudWatch Logs | `$0.50` | Retention set to 14 days to keep this down |
| **Total** | **`$5.25`** | |

Cross-check estimates against the [AWS Pricing Calculator](https://calculator.aws/).

Three things that moved the number most:

1. Memory tuning — `512 MB` optimal cost/performance point identified via Power Tuning
2. Log retention (default is *never expire*, which quietly becomes the largest bill on
   small projects)
3. Switching REST API → HTTP API would cut the gateway cost by ~70% if usage plans
   aren't needed

---

## Security

- IAM role scoped to the single DynamoDB table and the specific actions used — no
  wildcards
- No AWS keys in the repo or in GitHub Secrets; CD assumes a role via OIDC
- Encryption at rest on DynamoDB and CloudWatch Logs

---

## What I'd do differently for real production traffic

Being clear about the gaps is part of the point:

- Custom domain with ACM certificate instead of the default execute-api URL
- WAF in front of API Gateway for rate limiting by IP and common attack patterns
- Split into separate functions per operation (create/read/update/delete) so each can
  be tuned and scaled on its own
- DynamoDB Streams for an event-driven path instead of synchronous writes
- Provisioned concurrency if cold starts affect the user-facing p99
- Canary deploys with Lambda aliases and CodeDeploy, with automatic rollback on alarm
- Multi-region with DynamoDB global tables if the RTO calls for it

---

## Resources

- [AWS Lambda Documentation](https://docs.aws.amazon.com/lambda/)
- [API Gateway REST API Guide](https://docs.aws.amazon.com/apigateway/latest/developerguide/apigateway-use-lambda-proxy-integration.html)
- [DynamoDB Best Practices](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/best-practices.html)
- [k6 Documentation](https://k6.io/docs/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)

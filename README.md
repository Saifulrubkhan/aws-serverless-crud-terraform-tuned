# Serverless CRUD API — Terraform, CI/CD, and Lambda Power Tuning

A production-shaped serverless microservice on AWS: **API Gateway → Lambda → DynamoDB**.

Everything here is deployed with Terraform, shipped through GitHub Actions, and tuned
with AWS Lambda Power Tuning. Load-test numbers are measured before and after tuning.

---

## TL;DR

<!-- Fill these in from your own runs. Do not copy numbers you have not measured. -->

| Metric | Before tuning | After tuning | Change |
|---|---|---|---|
| Lambda memory | 128 MB | `___` MB | — |
| p95 latency | `___` ms | `___` ms | `___`% |
| Avg response time | `___` ms | `___` ms | `___`% |
| Throughput | `___` req/s | `___` req/s | `___`% |
| Cost per 1M invocations | $`___` | $`___` | `___`% |
| Error rate under load | `___`% | `___`% | — |

> The counter-intuitive part: more memory made this function **cheaper**, not more
> expensive. Details in [Power tuning](#power-tuning).

---

## Architecture

```
                    ┌──────────────┐
  Client / Postman ─▶  API Gateway  │  REST API, throttling, usage plan
                    └──────┬───────┘
                           │ AWS_PROXY integration
                    ┌──────▼───────┐
                    │    Lambda    │  Python 3.12, CRUD handler
                    │  (tuned MB)  │  X-Ray traced, structured JSON logs
                    └──────┬───────┘
                           │ IAM role, least privilege
                    ┌──────▼───────┐
                    │   DynamoDB   │  On-demand billing, PK: id
                    └──────────────┘
```

![Architecture diagram](docs/images/architecture.png)

**Why these services**

| Choice | Reason | What I rejected and why |
|---|---|---|
| Lambda over EC2/ECS | Spiky, low-volume traffic. No idle cost. | ECS Fargate: better for steady load and >15 min jobs. Not this workload. |
| DynamoDB over RDS | Single-key access pattern, no joins needed. Scales without me. | RDS: relational features I don't use, plus VPC and connection-pool overhead in Lambda. |
| API Gateway REST over HTTP API | Needed usage plans and request validation. | HTTP API is ~70% cheaper — worth switching if those features aren't needed. |
| On-demand DynamoDB | Unpredictable load during testing. | Provisioned capacity is cheaper at steady, predictable traffic. |

---

## Repository layout

```
.
├── terraform/
│   ├── main.tf              # Provider, backend, locals
│   ├── lambda.tf            # Function, IAM role, log group
│   ├── apigateway.tf        # REST API, stage, method, deployment
│   ├── dynamodb.tf          # Table definition
│   ├── observability.tf     # CloudWatch alarms, dashboard, X-Ray
│   ├── variables.tf
│   ├── outputs.tf           # API invoke URL
│   └── envs/
│       ├── dev.tfvars
│       └── prod.tfvars
├── src/
│   ├── handler.py           # CRUD logic
│   └── requirements.txt
├── tests/
│   ├── unit/                # pytest + moto, no AWS calls
│   └── load/
│       ├── crud.postman_collection.json
│       └── k6-script.js
├── .github/workflows/
│   ├── ci.yml               # lint, unit tests, tfsec, terraform plan
│   └── cd.yml               # terraform apply on merge to main
├── docs/
│   ├── images/              # screenshots
│   ├── cost-analysis.md
│   └── well-architected.md
└── README.md
```

---

## Prerequisites

- AWS account with programmatic access
- Terraform >= 1.6
- Python 3.12
- Postman (or k6) for load testing
- An S3 bucket + DynamoDB table for Terraform remote state

---

## Deploy

```bash
git clone https://github.com/<your-username>/<repo-name>.git
cd <repo-name>/terraform

terraform init -backend-config="bucket=<your-state-bucket>"
terraform plan  -var-file=envs/dev.tfvars
terraform apply -var-file=envs/dev.tfvars
```

Terraform outputs the invoke URL:

```bash
export API_URL=$(terraform output -raw api_invoke_url)
```

Smoke test:

```bash
curl -X POST "$API_URL/items" \
  -H 'Content-Type: application/json' \
  -d '{"id":"1","name":"test-item"}'

curl "$API_URL/items/1"
```

Tear down when you're done — this is the step tutorials forget and the reason people
get surprise bills:

```bash
terraform destroy -var-file=envs/dev.tfvars
```

---

## CI/CD

Two workflows, split so that pull requests never touch live infrastructure.

**`ci.yml`** — runs on every pull request:

1. `ruff` + `black --check` on the Python source
2. `pytest` unit tests against a mocked DynamoDB (`moto`) — no AWS credentials needed
3. `terraform fmt -check` and `terraform validate`
4. `tfsec` for infrastructure security scanning
5. `terraform plan`, with the plan posted as a PR comment

**`cd.yml`** — runs on merge to `main`:

1. `terraform apply` against dev
2. Smoke test against the deployed endpoint
3. Manual approval gate (GitHub Environments)
4. `terraform apply` against prod

Authentication uses **GitHub OIDC** with a short-lived assumed role. There are no
long-lived AWS keys stored in GitHub Secrets.

![CI pipeline](docs/images/ci-pipeline.png)

---

## Power tuning

[AWS Lambda Power Tuning](https://github.com/alexcasalboni/aws-lambda-power-tuning) is a
Step Functions state machine that runs your function at several memory settings and
plots execution time against cost.

Why this and not Compute Optimizer:

- Compute Optimizer needs 14 days of real invocations. Power Tuning needs one run.
- Compute Optimizer only recommends up to 1792 MB. Lambda goes to 10240 MB.
- Power Tuning lets you optimize for cost, speed, or a weighted balance of both.

Deploy it from the Serverless Application Repository, then:

```bash
aws stepfunctions start-execution \
  --state-machine-arn <power-tuning-arn> \
  --input '{
    "lambdaARN": "<your-lambda-arn>",
    "powerValues": [128, 256, 512, 1024, 1536, 3008],
    "num": 50,
    "payload": {"httpMethod":"GET","pathParameters":{"id":"1"}},
    "parallelInvocation": true,
    "strategy": "balanced"
  }'
```

![Power tuning results](docs/images/power-tuning.png)

**Results**

<!-- Replace with your actual output -->

| Memory | Avg duration | Cost per invocation | Cost per 1M |
|---|---|---|---|
| 128 MB | `___` ms | $`___` | $`___` |
| 256 MB | `___` ms | $`___` | $`___` |
| 512 MB | `___` ms | $`___` | $`___` |
| 1024 MB | `___` ms | $`___` | $`___` |
| 1536 MB | `___` ms | $`___` | $`___` |
| 3008 MB | `___` ms | $`___` | $`___` |

**Why the cheapest setting isn't the smallest**

Lambda bills GB-seconds: memory × duration. Doubling memory also roughly doubles CPU.
If the function finishes in less than half the time, you pay less overall despite the
larger size. That holds until the function stops being CPU-bound — past that point the
duration flattens and you're paying for memory you can't use. The bottom of the cost
curve is where those two effects cross.

**How the Well-Architected pillar you care about changes the answer**

| Priority | Pillar | Chosen memory | Trade-off accepted |
|---|---|---|---|
| Lowest cost | Cost Optimization | `___` MB | Slightly higher latency |
| Lowest latency | Performance Efficiency | `___` MB | Higher cost per invocation |
| Balanced | Both | `___` MB | Neither extreme |

I chose **`___` MB** because `___`.

---

## Load testing

Run against the deployed endpoint, before and after the memory change, so the
comparison is honest.

**Postman:** import `tests/load/crud.postman_collection.json`, then Collection Runner →
Performance → 100 virtual users, 5 minutes, ramp-up 30s.

**k6:**

```bash
k6 run tests/load/k6-script.js --env API_URL=$API_URL
```

![Load test before](docs/images/load-before.png)
![Load test after](docs/images/load-after.png)

| Run | VUs | Requests | Throughput | Avg | p95 | p99 | Errors |
|---|---|---|---|---|---|---|---|
| Before tuning | `___` | `___` | `___`/s | `___` ms | `___` ms | `___` ms | `___`% |
| After tuning | `___` | `___` | `___`/s | `___` ms | `___` ms | `___` ms | `___`% |

**Reading the results**

- The early p99 spike is cold starts. It settles once containers are warm.
- Watch `ConcurrentExecutions` against your account concurrency limit — that's the
  first ceiling you'll hit, before DynamoDB becomes a problem.
- p95 matters more than average. Averages hide the requests that make users leave.

---

## Observability

- **CloudWatch dashboard** — invocations, errors, duration p50/p95/p99, throttles,
  DynamoDB consumed capacity, on one screen
- **Alarms** — error rate > 1% over 5 min, p95 duration > `___` ms, any throttle
- **X-Ray** — end-to-end traces showing the API Gateway → Lambda → DynamoDB breakdown,
  which is how you find out the latency is DynamoDB and not your code
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

Assumptions: `___` requests/month, average duration `___` ms at `___` MB, us-west-2
pricing, `___` KB average item size.

| Component | Monthly cost | Notes |
|---|---|---|
| Lambda | $`___` | 1M free requests + 400,000 GB-s free tier |
| API Gateway REST | $`___` | $3.50 per million calls |
| DynamoDB on-demand | $`___` | Write units dominate |
| CloudWatch Logs | $`___` | Retention set to 14 days to keep this down |
| X-Ray | $`___` | Sampled, not every request |
| **Total** | **$`___`** | |

Full working in [`docs/cost-analysis.md`](docs/cost-analysis.md), cross-checked against
the [AWS Pricing Calculator](https://calculator.aws/).

Three things that moved the number most:

1. Memory tuning — `___`% off the Lambda line
2. Log retention (default is *never expire*, which quietly becomes the largest bill on
   small projects)
3. Switching REST API → HTTP API would cut the gateway cost by ~70% if usage plans
   aren't needed

---

## Security

- IAM role scoped to the single DynamoDB table and the specific actions used — no
  wildcards
- No AWS keys in the repo or in GitHub Secrets; CI assumes a role via OIDC
- `tfsec` runs on every pull request
- API Gateway request validation rejects malformed payloads before Lambda is invoked
- Throttling and a usage plan on the API stage
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

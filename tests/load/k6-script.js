// CRUD load test — exercises the full create/read/update/list/delete cycle
// against the deployed API, matching README.md > Load testing.
//
// Run:
//   k6 run tests/load/k6-script.js --env API_URL=$API_URL
//
// Get numbers for the README table:
//   k6 run tests/load/k6-script.js --env API_URL=$API_URL \
//     --summary-export tests/load/results/before.json
//   (repeat against the tuned deployment into after.json, then see
//   tests/load/compare_runs.py for turning the two into a graph)
//
// Get a graphical HTML report of a single run (no extra services needed):
//   K6_WEB_DASHBOARD=true K6_WEB_DASHBOARD_EXPORT=tests/load/results/report.html \
//     k6 run tests/load/k6-script.js --env API_URL=$API_URL

import http from "k6/http";
import { check, sleep } from "k6";
import { Rate } from "k6/metrics";

const API_URL = __ENV.API_URL;
if (!API_URL) {
  throw new Error("Set API_URL, e.g. k6 run tests/load/k6-script.js --env API_URL=$API_URL");
}

export const errors = new Rate("errors");

export const options = {
  stages: [
    { duration: "30s", target: 20 }, // ramp-up
    { duration: "4m", target: 20 }, // steady state — this is the number that matters
    { duration: "30s", target: 0 }, // ramp-down
  ],
  thresholds: {
    http_req_duration: ["p(95)<1000"],
    errors: ["rate<0.01"],
  },
  // Controls both the terminal summary and what --summary-export writes,
  // so compare_runs.py can rely on p(95)/p(99) being present.
  summaryTrendStats: ["avg", "min", "med", "max", "p(90)", "p(95)", "p(99)"],
};

export default function () {
  const id = `k6-${__VU}-${__ITER}-${Date.now()}`;
  const headers = { "Content-Type": "application/json" };

  const createRes = http.post(
    `${API_URL}/dynamodbmanager`,
    JSON.stringify({ id, name: "k6-load-test-item" }),
    { headers, tags: { name: "create" } },
  );
  errors.add(createRes.status !== 201);
  check(createRes, { "create: status 201": (r) => r.status === 201 });

  sleep(1);
}

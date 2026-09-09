# Campfire Incident Response Playbook (Live Demo & Production)

## Alert Routing & Communication
- **Emergency Channel:** `#alerts-campfire-devops` on Slack
- **Webhook Integration:** AWS SNS -> AWS Lambda / Chatbot -> Slack Incoming Webhook

---

## 1. Scenario: High CPU / Memory (>85%) on Container Clusters
- **Symptoms:** Grafana latency dashboard spikes past 1.0s; CloudWatch CPUUtilization alarms fire.
- **Action Steps:**
  1. Trigger manual ECS Auto-Scaling step:
     ```bash
     aws ecs update-service --cluster campfire-ecs-cluster --service go-gateway-service --desired-count 4
     ```
  2. Inspect container top processes:
     ```bash
     podman top campfire-backend
     ```
  3. Verify memory leaks via profiling logs (`X-Correlation-ID`).

---

## 2. Scenario: ALB Connection Drops or Emergency WSS Disconnects
- **Symptoms:** Mobile clients report SOS reconnection loops (`/ws/sos`).
- **Action Steps:**
  1. Confirm ALB Target Health:
     ```bash
     aws elbv2 describe-target-health --target-group-arn <TARGET_GROUP_ARN>
     ```
  2. Verify Stickiness and 3600s Idle Timeout attributes in ALB settings.
  3. Reload Nginx reverse proxy buffers:
     ```bash
     podman exec campfire-proxy nginx -s reload
     ```

---

## 3. Scenario: AI Service Outage (HTTP 500 / Timeout > 1.5s)
- **Automatic Mitigation:** Fallback engine engages automatically. Local cached offline risk weights serve the client.
- **Manual Verification:**
  ```bash
  curl -X POST http://localhost/api/risk/evaluate -H "X-Correlation-ID: debug-test"
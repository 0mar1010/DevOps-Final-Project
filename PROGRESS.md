# Capstone Progress Tracker

Update the "Current Status" and "Log" sections as you go. Keep entries short — a date and what changed.

## Phase Status

| Phase | What | Status |
|---|---|---|
| 1 | Kubernetes Foundation (namespaces, Deployments, Postgres StatefulSet, Ingress, Kustomize) | ✅ Done |
| 2 | GitOps (ArgoCD, root-app pattern, self-managed) | ✅ Done |
| 3 | Monitoring (Prometheus, Grafana, Alertmanager) | ✅ Done |
| 4 | Centralized Logging (Elasticsearch, Kibana, Filebeat) | 🔄 In progress — see below |
| 5 | AWS Cloud Integration (Terraform, ECS/EC2/S3/RDS) | ⬜ Not started |
| 6 | CI/CD Enhancement + docs/testing | ⬜ Not started |

## Current blocker (Phase 4)

- `logging-elasticsearch` ArgoCD app: `OutOfSync` — needs investigation (check if this is expected drift or a real issue)
- `logging-kibana` ArgoCD app: was `Missing`/`OutOfSync` — root cause found: the official Elastic Kibana Helm
  chart's `pre-install` hook hardcodes an HTTPS call to Elasticsearch, which fails unconditionally since
  `xpack.security.enabled: false` is set. Fixed by vendoring a patched copy of the chart
  (`charts/kibana/`) with the broken pre-install Job/Role/RoleBinding/ServiceAccount/ConfigMap removed,
  and pointing `argocd/apps/logging-kibana.yaml` at that local path instead of the public Elastic repo.
- Still need to confirm: did `root-app` actually pick up the updated Application spec, did the sync
  succeed, and does a real `kibana` pod come up clean.

## Known environment quirks (not project bugs — don't re-debug these)

- Hibernation stops Docker/k3d containers — always run `k3d cluster start capstone` + `kubectl cluster-info`
  first each session
- Windows reserves some local ports (checked via `netsh interface ipv4 show excludedportrange`) — port 8080
  is blocked on this machine, use 8082 instead for Traefik port-forwards
- k3d ships **Traefik**, not nginx — any Ingress must use `ingressClassName: traefik`
- `kubectl port-forward` dies the moment its terminal closes — not a bug, just how it works; re-run each session

## Log

- 2026-09-20 — Phase 1 (K8s foundation) complete
- 2026-09-20 — Phase 2 (ArgoCD GitOps) complete, self-managing
- 2026-09-22 — Phase 3 (Prometheus/Grafana) complete after fixing CRD annotation-size issue
  (`ServerSideApply=true`) and an operator reconciliation stall (`rollout restart`)
- 2026-09-22 — Fixed frontend hardcoded `localhost:5000` API URL → relative `/api` path; app fully working
  end-to-end through Ingress
- 2026-09-22 — Started Phase 4 (ELK), wrote initial ArgoCD apps for Elasticsearch/Kibana/Filebeat
- 2026-09-26 — Diagnosed Kibana pre-install hook as a genuine chart bug (hardcoded HTTPS); vendored
  patched chart into `charts/kibana/`, repointed ArgoCD app — sync verification still in progress

## Next up once Phase 4 is confirmed clean

1. Confirm `logging-kibana` syncs and a real Kibana pod runs
2. Verify logs are actually flowing: Filebeat → Elasticsearch → visible in Kibana
3. Decide on Logstash (optional, currently skipped in favor of Filebeat → Elasticsearch directly)
4. Begin Phase 5 — AWS Cloud Integration (Terraform, ECS/EC2/S3/RDS)

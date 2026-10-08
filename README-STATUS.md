# Implementation Status

## 📌 Implementation Status (my project)

_Last updated: 2026-10-08. Details and log: `PROGRESS.md`. Q&A and debugging notes: `PROJECT-QA.md`._

**Environment:** local k3d cluster (`capstone`), Traefik ingress, ArgoCD (app-of-apps, self-managed), Windows + PowerShell.
**Order change:** CI/CD (README Phase 7) was done before AWS (README Phase 6).

| README phase | Status | Notes |
| --- | --- | --- |
| 1 Kubernetes Foundation | ✅ Done | Kustomize base + dev/staging/production overlays, Postgres StatefulSet, Ingress |
| 2 Helm Charts | ⬜ Not tracked separately | Third-party charts are used through ArgoCD; no custom app chart yet |
| 3 ArgoCD & GitOps | ✅ Done | root-app pattern, ArgoCD manages itself |
| 4 Monitoring | ✅ Done | kube-prometheus-stack (Prometheus, Grafana, Alertmanager) via ArgoCD |
| 5 Centralized Logging | ✅ Done | Elasticsearch, Kibana and Filebeat over HTTPS; logs searchable via the `filebeat-*` data view |
| 7 CI/CD Enhancement | ✅ Core done | GitHub Actions (lint, test, build, Trivy, push to ghcr.io, tag bump) + GitLab CI (build + scan) |
| 6 AWS Cloud Integration | ⬜ Next | |

### CI/CD as built

```text
[git push] --+--> [GitHub] --> [GitHub Actions: lint+test -> build -> Trivy scan -> push ghcr.io]
             |                                              |
             |                                              v
             |                [update-tag: commit new image SHA to K8s/overlays/staging]
             |                                              |
             |                                              v
             |                     [ArgoCD syncs --> k3d cluster, namespace microservices]
             |
             '--> [GitLab] --> [GitLab CI: build images (no push) + Trivy scan of repo files]
```

- One `git push` goes to both GitHub and GitLab (two push URLs on `origin`).
- Only GitHub Actions commits the image tag back (`[skip ci]` plus `paths-ignore` prevent loops), so the two repos do not diverge.
- A `concurrency` group on the `update-tag` job stops two runs from editing the tag file at the same time.
- Trivy runs as a pinned container image (`0.69.2`), not as a floating GitHub Action tag.
- ghcr.io replaces ECR for now; an ECR push is added when AWS is done.
- Production promotion is a manual workflow (`promote-production.yml`) that writes a chosen commit SHA into the production overlay.
- Not done yet: Kubesec, OWASP Dependency-Check, SonarQube, notifications.

### Logging stack as built (differs from the plan above)

```text
[Filebeat DaemonSet] --https + CA + elastic login--> [Elasticsearch, 1 node]
                                                          |
                                                          v
                                  [Kibana] --https + kibana_system user-->
```

- **Logstash skipped by design:** Filebeat ships directly to Elasticsearch.
- **Single Elasticsearch node** (plan says 3): health is `yellow` because the replica shard cannot be placed on one node.
- **Security is on:** TLS between all components; Kibana uses the dedicated `kibana_system` user (Kibana 8 rejects `elastic`).
- **Remaining for this phase:** Kibana dashboards, log retention policy.

### Known gaps / honest limitations

- `kibana-system-credentials` is created by hand and is not in Git. Production answer: Sealed Secrets or External Secrets.
- The Elastic chart regenerates its secrets on sync; handled with an ArgoCD `ignoreDifferences` rule.
- The Kibana chart is vendored in `charts/kibana/` with local patches (broken pre-install hook removed, probe auth removed).
- Single-node Elasticsearch has no redundancy.
- The production overlay is updated in Git only; there is no ArgoCD production app.

### Lessons learned (for the presentation)

- Git changes reach the cluster only after the parent ArgoCD app (`root-app`) syncs.
- Render Helm charts locally (`helm template`) before pushing.
- CI builds and pushes; ArgoCD deploys. CI never touches the cluster.
- Automated writers can race: serialize them with `concurrency`.
- Pin third-party tools; check the data path (indices, image tags) before trusting a dashboard.

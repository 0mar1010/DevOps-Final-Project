# Capstone Progress Tracker

Last updated: 2026-10-08. Keep this file in the repo root and update it at the end of every session.

## Phase Status

My numbering differs from the course README (last column).
**Order change (2026-10-07): CI/CD (my Phase 6) was done BEFORE AWS (my Phase 5).**

| Phase | What | Status | README phase |
|---|---|---|---|
| 1 | Kubernetes Foundation (namespaces, Deployments, Postgres StatefulSet, Ingress, Kustomize) | ✅ Done | 1 |
| 2 | GitOps (ArgoCD, root-app pattern, self-managed) | ✅ Done | 3 |
| 3 | Monitoring (Prometheus, Grafana, Alertmanager) | ✅ Done | 4 |
| 4 | Centralized Logging (Elasticsearch, Kibana, Filebeat) | ✅ Done (2026-10-07) | 5 |
| 6 | CI/CD (GitHub Actions + GitLab CI) | ✅ Core done (2026-10-08). Open: test production gate, Kubesec/OWASP (optional) | 7 |
| 5 | AWS Cloud Integration (Terraform, ECS/EC2/S3/RDS) | ⬜ Next | 6 |

README Phase 2 (Helm chart for the app itself) has no row here and was never built. Decide later whether it is needed (the README grades "Helm charts properly structured").

## Phase 6 (CI/CD) — what is built

```
[git push] --+--> [GitHub] --> [GitHub Actions: lint+test -> build -> Trivy scan -> push to ghcr.io]
             |                                                   |
             |                                                   v
             |                     [update-tag job: commit new image SHA to K8s/overlays/staging  "[skip ci]"]
             |                                                   |
             |                                                   v
             |                          [ArgoCD app task-manager-app] --> [k3d cluster, namespace microservices]
             |
             '--> [GitLab] --> [.gitlab-ci.yml: build images (no push) + Trivy scan of repo files]
```

Files: `.github/workflows/ci.yml` (5 jobs: lint-test x2, build-scan-push x2, update-tag), `.github/workflows/promote-production.yml` (manual, writes the production overlay in Git only), `.gitlab-ci.yml` (3 jobs: build-image x2, trivy-scan).

Evidence (2026-10-08):
- GitHub run #6 (commit `58db3b1`) green, all 5 jobs, 4m 55s
- GitLab pipeline #2927787173 passed (3 jobs, 3m 57s)
- Before run #6, pods already ran `ghcr.io/0mar1010/backend|frontend:7a00718...` (the SHA in the staging overlay)
- The 5 bot commits look like `ci: deploy <sha> [skip ci]`

Checklist against the README CI/CD stages:
- ✅ lint, unit-test step, Docker build, Trivy image scan, push to registry (ghcr.io instead of ECR/Harbor)
- ✅ Deploy to staging through ArgoCD (the `dev` overlay is not used by ArgoCD)
- 🟡 Production gate: manual `workflow_dispatch` workflow (needs a 40-char SHA). Written, **not tested yet**. It only changes Git; there is no ArgoCD production app. Environment protection rules need a public repo on the free plan
- ⬜ Kubesec (manifests) and OWASP Dependency-Check: not added yet (optional, one at a time)
- ⬜ SonarQube, Slack/email notifications, blue-green/canary: skipped for now
- ⬜ ECR push: added when AWS is done

## Phase 4 status — logging (closed)

```
[Filebeat 1/1] --> [Elasticsearch 1/1] --> [Kibana 1/1]
   login: elastic       yellow health OK       login to ES: kibana_system
   CA mounted           (1 node, replica       secret: kibana-system-credentials
                        cannot be placed)      (created by hand, NOT in Git)
```

Open / optional: ES app shows `OutOfSync` on the StatefulSet only (cosmetic); Logstash skipped by design; README asks for 3 ES nodes, a retention policy and Kibana dashboards (currently 1 node, none, none); `kibana-system-credentials` is created by hand (production answer: Sealed Secrets or External Secrets).

## Known environment quirks (not project bugs — don't re-debug these)

- Hibernation stops Docker/k3d containers: run `k3d cluster start capstone` + `kubectl cluster-info` first each session
- A second k3d cluster (`demo`) may be running and eating RAM: `k3d cluster stop demo` if not needed
- Disk: Docker's WSL disk lives on D: and ran out of space on 2026-10-08. `docker builder prune -a -f` and `docker system prune -a -f` freed about 11 GB. Check `Get-PSDrive -PSProvider FileSystem` if Docker stops answering
- Windows reserves some local ports: port 8080 is blocked, use 8082 for the Traefik port-forward: `kubectl port-forward -n kube-system svc/traefik 8082:80` (dies when its terminal closes)
- k3d ships **Traefik**, not nginx: any Ingress must use `ingressClassName: traefik` (Kibana chart key is `ingress.className`)
- Editing the Windows hosts file needs an **Administrator** PowerShell
- PowerShell: run one `kubectl` per line, `<placeholders>` are invalid syntax, and a variable like `$k` holds `pod/name`
- GitLab prints a red "storage limit" message on every push. It belongs to my OLD GitLab project (LFS 9.5 GiB), not to `DevOps-Final-Project`. Pushes still work
- After CI commits an image tag, my local repo is behind: run `git pull` before the next `git push`
- `git reset --hard` also deletes files that were staged (`git add`) but never committed. Do not use it with staged files
- GitHub warnings about Node 20 and `ubuntu-latest` moving to Ubuntu 26 (2026-10-19) are notices only. Later: bump action versions if a run breaks
- Root `*.md` files do not trigger GitHub CI (`paths-ignore`) and do not trigger GitLab CI (`changes:` list), so doc commits are free

## Lessons learned (use in README/presentation)

- Git changes reach the cluster only after **root-app** syncs the Application files: refresh `root-app` first, then the child app
- Always run `helm template <name> ./charts/<chart>` locally before pushing a chart edit
- Elasticsearch 8 has security + TLS on by default: every client needs `https://`, credentials and the CA
- Kibana 8 refuses the `elastic` user: use `kibana_system` or a service-account token
- A single ES node goes `yellow` once indices have replicas: use `clusterHealthCheckParams: "wait_for_status=yellow&timeout=1s"`
- The Elastic chart regenerates its secrets on sync: `ignoreDifferences` on Secret `/data`
- CI should build and push images and commit the tag; ArgoCD deploys. CI never touches the cluster
- Two CI runs that edit the same file race each other: fixed with a `concurrency` group on `update-tag`
- Pin third-party tools (Trivy container `0.69.2`) instead of floating action tags
- Check the data path (indices, doc counts, pod image tags) before trusting a UI

## Recovery commands

If ES, Filebeat or Kibana show 401 or a password mismatch again (secret was regenerated):

```powershell
kubectl delete pod elasticsearch-master-0 -n logging
Start-Sleep -Seconds 10
kubectl wait --for=condition=Ready pod/elasticsearch-master-0 -n logging --timeout=300s
kubectl delete pod -n logging -l app=kibana
$f = kubectl get pods -n logging -o name | Where-Object { $_ -like "*filebeat*" }
kubectl delete $f -n logging
```

If the cluster is recreated, the hand-made Kibana secret must be recreated (run the first command, check `$pw.Length` prints 32, then the second):

```powershell
$pw = kubectl exec -n logging elasticsearch-master-0 -c elasticsearch -- sh -c 'PW=$(head -c 16 /dev/urandom | od -An -tx1 | tr -d " \n"); curl -fsk -u "elastic:$ELASTIC_PASSWORD" -X POST -H "Content-Type: application/json" https://localhost:9200/_security/user/kibana_system/_password -d "{\"password\":\"$PW\"}" > /dev/null && echo $PW'
kubectl create secret generic kibana-system-credentials -n logging --from-literal=username=kibana_system --from-literal=password=$pw
```

Get the `elastic` login password (copies it, doesn't print it):

```powershell
kubectl exec -n logging elasticsearch-master-0 -c elasticsearch -- sh -c 'printf %s "$ELASTIC_PASSWORD"' | Set-Clipboard
```

## Log

- 2026-09-20 — Phase 1 (K8s foundation) and Phase 2 (ArgoCD GitOps) complete
- 2026-09-22 — Phase 3 (Prometheus/Grafana) complete (`ServerSideApply=true`, operator `rollout restart`); fixed frontend API URL to relative `/api`; started Phase 4 (ELK)
- 2026-09-26 — Kibana pre-install hook diagnosed as a chart bug; vendored patched chart into `charts/kibana/`
- 2026-10-06 — Phase 4 fixes: indentation, HTTPS, `kibana_system` user, traefik ingress, probe auth removed, ES yellow check, `ignoreDifferences`. 49,587 docs in `filebeat-*`
- 2026-10-07 — Phase 4 closed (`filebeat-*` data view works). Decided CI/CD before AWS. Dual push to GitHub + GitLab set up. First GitHub Actions workflow pushed (runs #1-#2 failed)
- 2026-10-08 — Disk full on D: (Docker prune freed ~11 GB). Rewrote `ci.yml` (fail-fast off, setup-python/node, two-pass flake8, pinned Trivy image). Packages made public. Added `update-tag` job + `imagePullPolicy: IfNotPresent`. Added `promote-production.yml` and `.gitlab-ci.yml`. Run #4 lost a push race (two update-tag jobs); run #5 won. Pods now run ghcr.io images through ArgoCD. Added `concurrency` to `update-tag`; run #6 green, GitLab pipeline green. Phase 6 core done

## Next up

1. Test the production gate once (Actions > promote-production > Run workflow, paste a full SHA from a `ci: deploy <sha>` commit) and check `K8s/overlays/production/kustomization.yaml`
2. Optional, one at a time: Kubesec, then OWASP Dependency-Check
3. Phase 5 AWS: needs an AWS account (free tier). Install Terraform + AWS CLI, `aws configure` with an IAM user (not root), build `terraform/` step by step (VPC, then compute, then storage/db). If there is no AWS account yet, do the Helm chart (README Phase 2) first
4. Presentation: use the diagram in "Phase 6 — what is built" and the Lessons learned list

## Opening prompt for the next session

See `SESSION-HANDOFF.md`.

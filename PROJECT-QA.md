# Project Q&A and Debugging Notes

Last updated: 2026-10-08. This is ONE complete file: replace the old copy, do not append.
Parts: A) CI/CD in plain words, B) CI/CD decisions and problems, C) Phase 4 debugging and concepts, D) useful commands.

---

## A) CI/CD in plain words (Phase 6)

**Q: What is CI/CD here, in one picture?**
A: Every `git push` starts a robot that checks the code, builds the Docker images, scans them, and stores them in a registry. The robot then writes the new image version into a file in Git. ArgoCD (inside my cluster) sees that file change and updates the running app. I never deploy by hand.

```
[I push code] --> [GitHub Actions robot]
                    |  1. lint + test        (is the code OK?)
                    |  2. build images       (make the Docker images)
                    |  3. Trivy scan         (any known security holes?)
                    |  4. push to ghcr.io    (store the images)
                    |  5. update-tag         (write the new version into Git)
                    v
                 [Git: K8s/overlays/staging] --> [ArgoCD sees the change] --> [pods restart with the new image]
```

**Q: Workflow, pipeline, job, step: what is the difference?**
A: "Workflow" (GitHub) and "pipeline" (GitLab) mean the same thing: the whole automation defined in one YAML file. A **job** is one box in it that runs on its own machine (a "runner"). A **step** is one command or action inside a job. In `ci.yml`: workflow `ci`, jobs `lint-test`, `build-scan-push`, `update-tag`.

**Q: What are lint and flake8? What is `[lint+test]`?**
A: Lint = automatic code checking without running it, like a spell-checker. flake8 is the Python linter. `lint-test` is just the name of my first job: lint the backend (flake8) and frontend (npm lint), then run tests if any exist. It runs twice (backend and frontend) because of a "matrix".

**Q: What is Trivy, and what was the advisory?**
A: Trivy is a free security scanner. It reads a Docker image (or repo files) and lists known vulnerabilities (CVEs) and bad configuration. The advisory (read in an earlier session) said that in March 2026 most version tags of the `trivy-action` GitHub Action were replaced with malicious code. So my workflow does not use that action. It runs Trivy as a pinned Docker image, `ghcr.io/aquasecurity/trivy:0.69.2`.

**Q: What is ghcr.io?**
A: GitHub Container Registry: a place to store Docker images, like Docker Hub but run by GitHub. My packages `backend` and `frontend` are public, so the cluster can pull them without a password.

**Q: What is psycopg2 vs psycopg2-binary?**
A: The Python driver that lets Flask talk to PostgreSQL. `psycopg2-binary` is the same driver pre-compiled, so pip does not need a C compiler. It installed fine on the runner, so no change was needed.

**Q: What does the `update-tag` job do?**
A: It runs `kustomize edit set image backend=ghcr.io/0mar1010/backend:<sha> ...` in `K8s/overlays/staging`. That rewrites the `images:` block of `kustomization.yaml` with the new commit SHA, and the job commits and pushes it. ArgoCD watches that folder, so the pods get the new image. (kustomize is preinstalled on GitHub's Ubuntu runners: confirmed, the job worked.)

**Q: What are `[skip ci]` and `paths-ignore`?**
A: Two brakes against an endless loop. The bot's commit is a push, and a push starts CI, which would make another commit, and so on. `[skip ci]` in the commit message tells GitHub not to run. `paths-ignore: K8s/overlays/**` (and `*.md`) says that pushes touching only those files do not start CI either.

**Q: Why is the folder `K8s` and not `k8s`?**
A: Windows ignores case, but GitHub runners and ArgoCD run on Linux, where `k8s` and `K8s` are different folders. Always use the exact case.

**Q: Why does GitHub show 5 jobs and GitLab 3 jobs for the same commit?**
A: They are two different pipelines written in two different files, so they do different work on purpose.
- GitHub (`ci.yml`, 5 jobs): `lint-test` x2 (backend, frontend), `build-scan-push` x2, `update-tag`. It tests, scans, pushes, and is the only one that deploys.
- GitLab (`.gitlab-ci.yml`, 3 jobs): `build-image` x2 (backend, frontend; built but not pushed) and `trivy-scan` x1 (scans the repo files). It is a second platform that checks the code; it never deploys, so the two repos cannot diverge.
Durations differ too (4m 55s vs 3m 57s) for the same reason.

**Q: Why did the GitLab pipeline run when my commit only changed `ci.yml`?**
A: Its rules run on `main` when `backend/`, `frontend/`, `K8s/` or `.gitlab-ci.yml` changed. My push to GitLab contained two commits: the bot's tag commit (touches `K8s/`) and my `ci.yml` commit. The bot commit matched the rule. So after every bot commit, the next push will also start a GitLab pipeline (about 4 minutes of the 400 free minutes per month).

**Q: Why did the GitLab storage warning appear but pushes worked?**
A: The warning is for my old GitLab project (it has 9.5 GiB of LFS files). `DevOps-Final-Project` uses about 158 KiB. GitLab just prints the account-level message on every push.

**Q: What are Kubesec and OWASP Dependency-Check?**
A: Two more free scanners. Kubesec checks Kubernetes YAML for risky settings (root user, no limits). OWASP Dependency-Check checks `requirements.txt` and `package.json` for libraries with known vulnerabilities. Not added yet; add them one at a time so a failure is easy to attribute.

---

## B) CI/CD decisions and problems

**Q: Why CI/CD before AWS?**
A: Almost all of CI/CD does not need AWS. Only the ECR push and ECS deploy do, and those become extra steps later.

**Q: How does CI deploy if GitHub's runners cannot reach my local cluster?**
A: It does not deploy directly. CI builds and pushes the image and commits the tag to Git; ArgoCD inside the cluster does the deploy (GitOps: CI builds, ArgoCD deploys).

**Q: Why GitHub Actions AND GitLab CI?**
A: The README names GitLab CI/CD, but the code is on GitHub. Building it on GitHub first and porting a smaller version to GitLab shows CI/CD as a concept, not one vendor's syntax.

**Q: How does one `git push` reach both?**
A: Two push URLs on `origin`:
```powershell
git remote set-url --add --push origin https://github.com/0mar1010/DevOps-Final-Project.git
git remote set-url --add --push origin https://gitlab.com/Omar-Samir-GitLab/DevOps-Final-Project.git
git remote -v
```
`git remote -v` shows `(fetch)` once and `(push)` twice.

**Problems we hit in Phase 6 (and the fix):**

| Problem | Cause | Fix |
|---|---|---|
| First workflow failed in 7 seconds | Guessed settings: `npm ci` without lockfile, plain `pip install`, no tests, strict flake8 | Rewrote `ci.yml`: `setup-python`/`setup-node`, lockfile check, `--passWithNoTests`, two-pass flake8 |
| One failing matrix job hid the other | GitHub cancels siblings by default | `fail-fast: false` |
| Pods could not use CI images | Manifests used `backend:local` with `imagePullPolicy: Never` | Changed to `IfNotPresent`, images come from ghcr.io via the staging overlay |
| `paths-ignore` did not match | Lowercase `k8s/` vs real folder `K8s/` | Fixed the case |
| Replace command rewrote 12 files | `Get-Content | Set-Content` changes line endings/encoding | Raw `[IO.File]` read/write, only the 2 deployment files change |
| Docker "backend not responding", VS Code update failed | D: disk full (Docker WSL disk 31.8 GB) | `docker builder prune -a -f`, `docker system prune -a -f`, emptied recycle bin (~11 GB freed) |
| Run #4 `update-tag` failed: merge CONFLICT | Runs #4 and #5 started together and both edited the staging file; #5 pushed first | `concurrency: group: update-tag` so only one tag-bump runs at a time (run #6 green) |
| `kubectl annotate application task-manager` NotFound | Real name is `task-manager-app` | Use `kubectl get applications -n argocd` to read names |
| 3 staged `.md` files vanished | `git reset --hard` removes staged-but-uncommitted files | Don't reset with staged files; keep copies |

**Q: What is a race condition (run #4 vs run #5)?**
A: Two automatic writers changing the same file at the same time. Whoever pushes second gets a conflict. A `concurrency` group makes the second job wait until the first finishes, and its checkout then already contains the first job's commit.

**Q: What is the production gate?**
A: `promote-production.yml` runs only when I click "Run workflow" and enter a 40-character commit SHA. It writes that tag into `K8s/overlays/production/kustomization.yaml`. A person decides, so it acts as an approval gate. It only changes Git (no ArgoCD production app exists). Real "required reviewers" on a GitHub environment need a public repo on the free plan.

---

## C) Phase 4 (logging) debugging and concepts

### Debugging saga — Kibana/Elasticsearch/Filebeat, resolved (2026-10-06)

1. **Fix never reached the cluster.** One over-indented env line in `deployment.yaml`, so the chart didn't render and ArgoCD applied nothing.
2. **App files edited but still old in the cluster.** `argocd/apps/logging-*.yaml` are applied by `root-app`; `root-app` had to be refreshed and synced.
3. **`elastic` user is forbidden in Kibana 8.** Crash log: `value of "elastic" is forbidden`. Fix: a `kibana_system` user with a random password in secret `kibana-system-credentials` (created by hand), referenced with `elasticsearchCredentialSecret`.
4. **Elasticsearch stuck 0/1.** Readiness probe used `http://` on an HTTPS-only server. Fix: `protocol: https` and `clusterHealthCheckParams: "wait_for_status=yellow&timeout=1s"`.
5. **Filebeat 401.** The Elastic chart regenerates its password secret on sync. Restarting the ES pod fixes it; prevented with `ignoreDifferences` on Secret `/data`.
6. **Kibana 0/1 though healthy.** The readiness probe's basic-auth got 403. Removed the 3-line auth block in `charts/kibana/templates/deployment.yaml`.
7. **Ingress ignored.** Class was `nginx`; Kibana chart key is `ingress.className`, set to `traefik` (it was also nested under `resources:` by mistake).

### Concepts

**Q: What is `root-app`?**
A: The "app of apps". It watches `argocd/apps/` in Git and creates/updates the child Application objects. A change to a child's YAML only takes effect after `root-app` syncs it.

**Q: Why does the Kibana chart live in `charts/kibana/`?**
A: The official chart's pre-install hook hardcoded an HTTPS call that failed, so I vendored a copy and edited it. Consequence: run `helm template` locally before every push.

**Q: What does `ignoreDifferences` do?**
A: Tells ArgoCD to ignore some fields when comparing Git to the cluster. Here: Secret `/data`, because the Elastic chart generates random passwords/certs on each render. `RespectIgnoreDifferences=true` makes sync obey the rule too.

**Q: Why is Elasticsearch `yellow`?**
A: Shards have 1 primary and 1 replica; one node cannot hold both, so the replica stays unassigned. Data is safe and searchable, just without redundancy. Production uses 3 nodes (green).

**Q: Did logs actually flow?**
A: Yes: `_cat/indices` showed `.ds-filebeat-8.5.1-2026.10.06-000001` with 49,587 documents. Check this before trusting the UI.

**Q: What are 302, 401 and 403?**
A: 302 = redirect (Kibana sending a visitor to login), good. 401 = not authenticated. 403 = authenticated but not allowed.

---

## D) Useful commands

```powershell
# First five minutes of every session
k3d cluster start capstone
kubectl cluster-info
kubectl get pods -A
kubectl get applications -n argocd

# Which image does each app pod run? (should show ghcr.io/0mar1010/...:<sha>)
kubectl get pods -n microservices -o jsonpath="{range .items[*]}{.metadata.name}{'  '}{.spec.containers[*].image}{'\n'}{end}"

# Force ArgoCD to re-check Git now
kubectl annotate application task-manager-app -n argocd argocd.argoproj.io/refresh=hard --overwrite

# Which app resource is OutOfSync
(kubectl get application <name> -n argocd -o json | ConvertFrom-Json).status.resources | Where-Object { $_.status -eq "OutOfSync" } | Select-Object kind,name

# Why is an ArgoCD app failing to render
kubectl get application <name> -n argocd -o jsonpath="{.status.conditions}"

# Is Filebeat shipping
kubectl exec -n logging <filebeat-pod> -- filebeat test output
kubectl exec -n logging elasticsearch-master-0 -c elasticsearch -- sh -c 'curl -sk -u "elastic:$ELASTIC_PASSWORD" "https://localhost:9200/_cat/indices?v"'

# Number the lines of a file to find a YAML error
$i=1; Get-Content <file> | ForEach-Object { "{0,3}: {1}" -f $i++, $_ }

# Disk space check
Get-PSDrive -PSProvider FileSystem
```

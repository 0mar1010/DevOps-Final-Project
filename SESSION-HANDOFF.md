# Session Handoff — how to start the next chat so it works exactly like this one

Last updated: 2026-10-08.

## 1. Files to upload (4 files, all from the repo root)

| File | Note |
|---|---|
| `PROGRESS.md` | the tracker (full file) |
| `PROJECT-QA.md` | ONE complete file, never append to it |
| `FINAL-PROJECT-README.md` | the course README with my status section at the bottom |
| `SESSION-HANDOFF.md` | this file (it holds the style rules) |

Optional, for fresh facts: the output of `kubectl get pods -A` and `kubectl get applications -n argocd`.
Keep only ONE copy of each file in the folder. Old copies go to `..\old-docs`.

## 2. Opening prompt (copy everything in the box)

Edit the lines in [brackets] before sending.

```
Continuing my DevOps capstone (Cloud-Native DevSecOps Pipeline). Attached: PROGRESS.md,
PROJECT-QA.md, the README and SESSION-HANDOFF.md. Use them for context instead of
re-explaining things I've already covered.

Status: Phases 1-4 done (K8s, ArgoCD GitOps, Prometheus/Grafana, ELK logging).
Phase 6 (CI/CD) core is done: GitHub Actions (lint, test, build, Trivy, push to ghcr.io,
tag bump in K8s/overlays/staging) + ArgoCD deploy, and GitLab CI (build + scan).
[Production gate test: DONE / NOT DONE]. [Kubesec/OWASP: DONE / SKIPPED / NOT DONE]
Next: Phase 5 (AWS) or the Helm chart. [AWS account ready: YES / NO]

Today I want to: [implement / understand / both].

How to answer me (follow every time):
1. English only.
2. Explain each new concept in plain words (1-2 lines). I follow only part of the
   CI/CD and AWS topics, so no jargon without an explanation.
3. When you give commands: first explain what each command does, then put ALL the
   commands in ONE code box (PowerShell, Windows). Mark STOP points between steps.
4. When you edit files, add a "Key Points of Change" list.
5. Explain architecture with ASCII bracket/arrow diagrams.
6. Give complete answers without needless follow-up questions. Keep it short: I want
   to finish the project soon.
7. Say when something is a guess, and correct earlier mistakes openly.
8. At the end of the session, update PROGRESS.md, PROJECT-QA.md, the README status
   section and this file, as full replacement files.
```

## 3. How to apply the updated files (run in the repo root)

1. Save the new `PROGRESS.md`, `PROJECT-QA.md`, `README-STATUS.md`, `SESSION-HANDOFF.md` into the repo root (overwrite).
2. Merge the status section into the README. This replaces any older status section, so it is safe to run every time:

```powershell
$r = [IO.File]::ReadAllText((Resolve-Path FINAL-PROJECT-README.md).Path)
$s = [IO.File]::ReadAllText((Resolve-Path README-STATUS.md).Path)
$i = $r.IndexOf("## 📌 Implementation Status")
if ($i -ge 0) { $r = $r.Substring(0, $i) }
$r = $r.TrimEnd() + "`n`n---`n`n" + $s.Trim() + "`n"
[IO.File]::WriteAllText((Resolve-Path FINAL-PROJECT-README.md).Path, $r, (New-Object Text.UTF8Encoding($false)))
```

3. Commit only the docs (root `.md` files do not start CI):

```powershell
git pull
git add FINAL-PROJECT-README.md PROGRESS.md PROJECT-QA.md README-STATUS.md SESSION-HANDOFF.md
git commit -m "docs: update status, Q&A and handoff"
git push
```

## 4. First five minutes of every session

```powershell
k3d cluster start capstone
kubectl cluster-info
kubectl get pods -A
kubectl get applications -n argocd
git pull
```

Only if you need Kibana, start the port-forward in a NEW terminal and keep it open:

```powershell
kubectl port-forward -n kube-system svc/traefik 8082:80
```

## 5. End of every session

Ask: "Update PROGRESS.md, PROJECT-QA.md, README-STATUS.md and SESSION-HANDOFF.md with what we did today, as full files." Then overwrite the old files and run section 3.

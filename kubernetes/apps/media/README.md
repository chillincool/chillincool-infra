# Apps (default namespace) — notes

This repository contains Flux-managed HelmReleases for several \*arr apps (sonarr, radarr, lidarr, prowlarr, etc).

Why envFrom didn't work earlier

- Until recently, the `common` library templates did not render `.Values.envFrom` into the container spec — they only mapped `.Values.env` into `env:` entries. That is why `envFrom:` in HelmRelease values did nothing in the rendered manifest.

Upstream change

- The upstream chart (`chillincool/charts`) now supports `.Values.envFrom` in the common deployment templates. That means we can and will switch our HelmReleases back to the simpler `envFrom:` form so each release can import secret keys with a single line.

Files updated (now using envFrom)

- `kubernetes/apps/default/sonarr-4k/app/helmrelease.yaml`
- `kubernetes/apps/default/sonarr-anime/app/helmrelease.yaml`
- `kubernetes/apps/default/sonarr/app/helmrelease.yaml`
- `kubernetes/apps/default/radarr/app/helmrelease.yaml`
- `kubernetes/apps/default/radarr-4k/app/helmrelease.yaml`
- `kubernetes/apps/default/lidarr/app/helmrelease.yaml`
- `kubernetes/apps/default/prowlarr/app/helmrelease.yaml`

How to verify locally / in-cluster

1. Ensure the Secret exists in the `default` namespace (Flux should apply `kubernetes/apps/default/secrets.yaml`):

```bash
kubectl get secret sonarr-4k-secret -n default -o yaml
```

2. Ensure the HelmRelease rendered Deployment has `env:` entries (not `envFrom`):

```bash
kubectl get helmrelease sonarr-4k -n default -o yaml | grep -n "env: - name" -n || true
kubectl get deploy -n default sonarr-4k -o yaml | yq '.spec.template.spec.containers[] | {name: .name, env: .env}'
```

3. If the secret exists but pods were created before the secret was available, restart the Deployment:

```bash
kubectl rollout restart deploy sonarr-4k -n default
```

Notes

- We initially used explicit `env` mappings to make things work with older charts. Because the upstream charts now support `envFrom`, we've switched back to the cleaner `envFrom` approach in the HelmRelease values.

If you want, I can prepare the follow-up PR to add `envFrom` support in the `common` library/chart so you can keep `envFrom` in values across charts — just tell me and I’ll prepare a minimal template change + tests.

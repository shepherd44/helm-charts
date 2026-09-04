# Helm Charts

Charts published through GitHub Pages at <https://shepherd44.github.io/helm-charts/docs>.

## Use

```shell
helm repo add shepherd44 https://shepherd44.github.io/helm-charts/docs
helm repo update
helm search repo shepherd44
```

## Charts

| chart | app | notes |
|---|---|---|
| `cp-schema-registry` | Confluent Schema Registry | |
| `mongodb-sharded` | MongoDB 8.0 | fork of `bitnami/mongodb-sharded`, images from [shepherd44/containers](https://github.com/shepherd44/containers) |
| `common` | — | bitnami library chart, dependency only, not published |

## Release

```shell
CHART=mongodb-sharded

# charts with dependencies only
helm dependency update ./charts/$CHART

helm package ./charts/$CHART --destination docs
helm repo index docs --url https://shepherd44.github.io/helm-charts/docs --merge docs/index.yaml
```

Then commit `docs/` and push to `main`. GitHub Pages serves the repo root of `main`,
so `docs/index.yaml` is live once the Pages build finishes.

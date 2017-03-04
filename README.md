# CTLT's Collection of Helm Charts for Kubernetes

## Enable this Repo

```bash
helm repo add ctlt https://ubc.github.io/charts
```
## Install a Chart

```bash
helm install ctlt/CHART
```

## Update a Chart
* Update chart source and version
* Run the following command to release a new version

```bash
cd docs
helm package ../CHART_NAME
helm repo index . --url https://ubc.github.io/charts
```

For more information:

* Helm: https://github.com/kubernetes/helm

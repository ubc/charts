# MariaDB Helm Chart

A Helm chart for deploying a MariaDB instance using the [mariadb-operator](https://github.com/mariadb-operator/mariadb-operator).

This chart provides a highly configurable way to deploy MariaDB on Kubernetes, with support for replication, backups, metrics, and automatic database/user creation.

## Prerequisites

* Kubernetes 1.19+
* Helm 3.2+
* The [mariadb-operator](https://github.com/mariadb-operator/mariadb-operator) must be installed in your cluster.

## Installing the Chart

To install the chart with the release name `my-release`:

```bash
helm install my-release .
```

## Uninstalling the Chart

To uninstall/delete the `my-release` deployment:

```bash
helm uninstall my-release
```

## Configuration

The following table lists the configurable parameters of the MariaDB chart and their default values.

| Parameter | Description | Default |
| --- | --- | --- |
| `architecture` | MariaDB architecture. Allowed values: `standalone` or `replication`. | `standalone` |
| `image.registry` | Global Docker image registry. | `docker.io` |
| `image.repository` | The image repository to use for the MariaDB instance. | `bitnami/mariadb` |
| `image.tag` | The image tag to use. Overrides the chart's `appVersion`. | `"12.0.2-debian-12-r0"` |
| `image.pullPolicy` | The image pull policy. | `IfNotPresent` |
| `auth.existingSecret` | Name of an existing Kubernetes secret to use for authentication. | `mariadb-root-password` |
| `auth.secretKeys.rootPasswordKey` | Key in the secret containing the root password. | `password` |
| `primary.containerPorts.mysql` | The port to expose MariaDB on. | `3306` |
| `primary.persistence.enabled` | Enable or disable persistent storage for the primary instance. | `true` |
| `primary.persistence.size` | The size of the persistent volume for the primary instance. | `10Gi` |
| `primary.persistence.accessModes` | The access modes for the primary persistent volume. | `[ReadWriteOnce]` |
| `primary.configuration` | Custom MariaDB configuration for the primary instance. | `[mysqld]\nbind-address=0.0.0.0\ndefault_storage_engine=InnoDB\nbinlog_format=row\ninnodb_autoinc_lock_mode=2\nmax_allowed_packet=256M` |
| `primary.resources` | The CPU and memory resources for the primary MariaDB instance. | `{}` |
| `secondary.replicaCount` | The number of secondary replicas to create (if `architecture` is `replication`). | `2` |
| `replication.enabled` | Enable or disable replication. (Note: Bitnami chart uses `architecture: replication` for this). | `false` |
| `replication.replicas` | The number of replicas to create. | `2` |
| `replication.semiSync.enabled` | Enable or disable semi-synchronous replication. | `true` |
| `replication.semiSync.ackReplicas` | The number of replicas that must acknowledge a transaction before the primary commits it. | `1` |
| `backup.enabled` | Enable or disable backups. (Note: Bitnami chart handles backups via a separate chart). | `false` |
| `backup.schedule` | The cron schedule for backups. | `"0 0 * * *"` |
| `backup.storage.size` | The size of the persistent volume for backups. | `10Gi` |
| `backup.storage.accessModes` | The access modes for the backup persistent volume. | `[ReadWriteOnce]` |
| `backup.retention.keep` | The number of backups to retain. | `3` |
| `restore.enabled` | Enable or disable restore. (Note: Bitnami chart handles restores via a separate chart). | `false` |
| `restore.backupName` | The name of the backup to restore from. | `""` |
| `metrics.enabled` | Enable or disable metrics. | `false` |
| `metrics.exporter.image.repository` | The image repository for the metrics exporter. | `prom/mysqld-exporter` |
| `metrics.exporter.image.tag` | The image tag for the metrics exporter. | `v0.14.0` |
| `metrics.exporter.image.pullPolicy` | The image pull policy for the metrics exporter. | `IfNotPresent` |
| `metrics.serviceMonitor.enabled` | Enable or disable the ServiceMonitor. | `true` |
| `metrics.serviceMonitor.interval` | The scrape interval for the ServiceMonitor. | `30s` |
| `metrics.serviceMonitor.scrapeTimeout` | The scrape timeout for the ServiceMonitor. | `10s` |
| `databases` | A list of databases to create. (Note: Bitnami chart has a different way of creating databases). | `[]` |

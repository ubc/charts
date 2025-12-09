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
| `image.repository` | The image repository to use for the MariaDB instance. | `mariadb` |
| `image.tag` | The image tag to use. | `"10.6"` |
| `image.pullPolicy` | The image pull policy. | `IfNotPresent` |
| `auth.existingSecret` | Name of an existing Kubernetes secret to use for authentication. | `""` |
| `auth.secretKeys.rootPasswordKey` | Key in the secret containing the root password. | `password` |
| `auth.database` | Database to be created on startup. | `""` |
| `auth.username` | User to be created on startup. | `""` |
| `auth.password` | Password for the user. | `""` |
| `auth.replicationPassword` | Password for replication user. | `""` |
| `myCnf` | Custom MariaDB configuration (my.cnf). | `[mariadb]\nbind-address=0.0.0.0\ndefault_storage_engine=InnoDB\nbinlog_format=row\ninnodb_autoinc_lock_mode=2\nmax_allowed_packet=256M` |
| `resources.limits.cpu` | CPU limits for the MariaDB container. | `500m` |
| `resources.limits.memory` | Memory limits for the MariaDB container. | `1Gi` |
| `resources.requests.cpu` | CPU requests for the MariaDB container. | `200m` |
| `resources.requests.memory` | Memory requests for the MariaDB container. | `256Mi` |
| `persistence.size` | The size of the persistent volume. | `10Gi` |
| `service.type` | Kubernetes Service type for the common service. | `ClusterIP` |
| `service.annotations` | Annotations for the common service. | `{}` |
| `primary.containerPorts.mysql` | The port to expose MariaDB on. | `3306` |
| `primary.automaticFailover` | Enable automatic failover for primary. | `true` |
| `primary.service.type` | Kubernetes Service type for the primary instance. | `ClusterIP` |
| `primary.service.annotations` | Annotations for the primary service. | `{}` |
| `secondary.enabled` | Enable secondary replicas. | `false` |
| `secondary.replicaCount` | The number of secondary replicas to create. | `2` |
| `secondary.service.type` | Kubernetes Service type for secondary instances. | `ClusterIP` |
| `secondary.service.annotations` | Annotations for the secondary service. | `{}` |
| `secondary.semiSync.enabled` | Enable semi-synchronous replication. | `true` |
| `backup.enabled` | Enable or disable backups. | `false` |
| `backup.schedule` | The cron schedule for backups. | `"0 0 * * *"` |
| `backup.storage.size` | The size of the persistent volume for backups. | `10Gi` |
| `backup.storage.accessModes` | The access modes for the backup persistent volume. | `[ReadWriteOnce]` |
| `backup.retention.keep` | The number of backups to retain. | `3` |
| `restore.enabled` | Enable or disable restore. | `false` |
| `restore.backupName` | The name of the backup to restore from. | `""` |
| `metrics.enabled` | Enable or disable metrics. | `false` |
| `metrics.exporter.image.repository` | The image repository for the metrics exporter. | `prom/mysqld-exporter` |
| `metrics.exporter.image.tag` | The image tag for the metrics exporter. | `v0.15.1` |
| `metrics.exporter.image.pullPolicy` | The image pull policy for the metrics exporter. | `IfNotPresent` |
| `metrics.serviceMonitor.enabled` | If true, a ServiceMonitor resource will be created. | `false` |
| `metrics.serviceMonitor.interval` | The scrape interval for the ServiceMonitor. | `30s` |
| `metrics.serviceMonitor.scrapeTimeout` | The scrape timeout for the ServiceMonitor. | `10s` |
| `databases` | List of custom databases and users to create (each item should have `name`, `user`, `password`). | `[]` |

## Testing
```bash
# standard
helm install --debug mariadb-test .
# replication
helm install --debug mariadb-test --set architecture=replication --set secondary.replicaCount=4 .
# with custom user and database
helm install --debug mariadb-test --set architecture=replication --set secondary.replicaCount=4  --set auth.database=dbtest --set auth.username=dbtest .

# clean up
helm uninstall mariadb-test
```

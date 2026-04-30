# MediaWiki

[MediaWiki](https://www.mediawiki.org) is an extremely powerful, scalable software and a feature-rich wiki implementation that uses PHP to process and display data stored in a database, such as MySQL.

NOTE: This chart is based on https://github.com/kubernetes/charts/tree/master/stable/mediawiki

## TL;DR;

```console
$ helm install stable/mediawiki
```

## Introduction

This chart bootstraps a [MediaWiki](https://github.com/ubc/mediawiki-docker) deployment on a [Kubernetes](http://kubernetes.io) cluster using the [Helm](https://helm.sh) package manager.

It also packages the UBC [`mariadb`](https://github.com/ubc/charts/tree/master/mariadb) chart (operator-driven, via [mariadb-operator](https://github.com/mariadb-operator/mariadb-operator)) to provision the database, user, and grant required by MediaWiki. To use a database that is managed outside the cluster, disable the subchart and set the `externalDatabase.*` parameters.

## Prerequisites

- Kubernetes 1.4+ with Beta APIs enabled
- PV provisioner support in the underlying infrastructure

## Installing the Chart

To install the chart with the release name `my-release`:

```console
$ helm install --name my-release stable/mediawiki
```

The command deploys MediaWiki on the Kubernetes cluster in the default configuration. The [configuration](#configuration) section lists the parameters that can be configured during installation.

> **Tip**: List all releases using `helm list`

## Uninstalling the Chart

To uninstall/delete the `my-release` deployment:

```console
$ helm delete my-release
```

The command removes all the Kubernetes components associated with the chart and deletes the release.

## Configuration

The following tables lists the configurable parameters of the MediaWiki chart and their default values.

|              Parameter               |               Description                |                         Default                         |
|--------------------------------------|------------------------------------------|---------------------------------------------------------|
| `image`                              | MediaWiki image                          | `ubcctlt/mediawiki:{VERSION}`                           |
| `imagePullPolicy`                    | Image pull policy                        | `Always` if `imageTag` is `latest`, else `IfNotPresent` |
| `mediawikiUser`                      | User of the application                  | `user`                                                  |
| `mediawikiPassword`                  | Application password                     | _random 10 character long alphanumeric string_          |
| `mediawikiEmail`                     | Admin email                              | `user@example.com`                                      |
| `mediawikiName`                      | Name for the wiki                        | `My Wiki`                                               |
| `smtpHost`                           | SMTP host                                | `nil`                                                   |
| `smtpPort`                           | SMTP port                                | `nil`                                                   |
| `smtpHostID`                         | SMTP host ID                             | `nil`                                                   |
| `smtpUser`                           | SMTP user                                | `nil`                                                   |
| `smtpPassword`                       | SMTP password                            | `nil`                                                   |
| `db.enabled`                         | Provision MariaDB via the UBC `mariadb` subchart (operator-managed). Set to `false` to use an externally managed database via `externalDatabase.*`. | `true` |
| `db.architecture`                    | `standalone` or `replication` (forwarded to the `mariadb` subchart). | `standalone` |
| `db.auth.database`                   | Database name to create. The subchart emits a `Database` CR for this name. | `mediawiki` |
| `db.auth.username`                   | Application user to create. The subchart emits matching `User`+`Grant` CRs and stores a generated password in the secret `<release>-db-user-password` under key `password-<username>`. | `wiki` |
| `db.auth.password`                   | Override the generated password (optional). | _generated_ |
| `db.auth.existingSecret` / `db.auth.userPasswordKey` | Use an existing secret for the user password instead of the generated one. | _unset_ |
| `db.persistence.size`                | PVC size for the MariaDB instance. | `10Gi` |
| `db.persistence.storageClassName`    | Storage class for the MariaDB PVC. | _cluster default_ |
| `externalDatabase.host`              | Hostname of an externally managed MariaDB. Required when `db.enabled=false`. | `""` |
| `externalDatabase.port`              | Port of the external database. | `3306` |
| `externalDatabase.user` / `externalDatabase.database` | Credentials and database for the external server. | `wiki` / `mediawiki` |
| `externalDatabase.password`          | Password for the external user. Stored in a chart-owned secret unless `existingSecret` is set. | `""` |
| `externalDatabase.existingSecret` / `externalDatabase.existingSecretPasswordKey` | Resolve the external password from an existing secret. | _unset_ |
| `serviceType`                        | Kubernetes Service type                  | `LoadBalancer`                                          |
| `persistence.enabled`                | Enable persistence using PVC             | `true`                                                  |
| `persistence.apache.storageClass`    | PVC Storage Class for Apache volume      | `nil` (uses alpha storage class annotation)  |
| `persistence.apache.accessMode`      | PVC Access Mode for Apache volume        | `ReadWriteOnce`                                         |
| `persistence.apache.size`            | PVC Storage Request for Apache volume    | `1Gi`                                                   |
| `persistence.mediawiki.storageClass` | PVC Storage Class for MediaWiki volume   | `nil` (uses alpha storage class annotation)   |
| `persistence.mediawiki.accessMode`   | PVC Access Mode for MediaWiki volume     | `ReadWriteOnce`                                         |
| `persistence.mediawiki.size`         | PVC Storage Request for MediaWiki volume | `8Gi`                                                   |
| `resources`                          | CPU/Memory resource requests/limits      | Memory: `512Mi`, CPU: `300m`                            |


Specify each parameter using the `--set key=value[,key=value]` argument to `helm install`. For example,

```console
$ helm install --name my-release \
  --set adminUser=admin,adminPassword=password,db.auth.password=secretpassword \
    stable/mediawiki
```

The above command sets the MediaWiki administrator account username and password to `admin` and `password` respectively, and pins the application's database password to `secretpassword` (otherwise the subchart generates a random one).

To point the chart at an externally managed database instead:

```console
$ helm install my-release . \
  --set db.enabled=false \
  --set externalDatabase.host=db.example.com \
  --set externalDatabase.user=wiki \
  --set externalDatabase.database=mediawiki \
  --set externalDatabase.password=secretpassword
```

Alternatively, a YAML file that specifies the values for the above parameters can be provided while installing the chart. For example,

```console
$ helm install --name my-release -f values.yaml stable/mediawiki
```

> **Tip**: You can use the default [values.yaml](values.yaml)

## Persistence

Persistent Volume Claims are used to keep the data across deployments. This is known to work in GCE, AWS, and minikube.
See the [Configuration](#configuration) section to configure the PVC or to disable persistence.

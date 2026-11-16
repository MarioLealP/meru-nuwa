# meru-baseline

What Meru puts in every app namespace (and environment namespace) whatever the app's own values say. Meru/meru's
ApplicationSets render it next to the app's `nuwa-app` release and pin its version; the app's repo can't change it.

Today: three NetworkPolicies.

- `meru-default-deny` - every pod closed both ways. Policies add up, so the app's own (nuwa-app `networkPolicy`)
  opens what the app needs; an app that turns its own off stays closed.
- `meru-database` - the namespace's CNPG pods: 5432 from the namespace's own pods and from `databaseClients`
  (deploy/meru.yaml), 8000 (status) from CNPG's operator and the kubelet; out to DNS, the Kubernetes API and the
  backup store (`backupStore`: Meru/garage's S3 API, for WAL archiving + base backups).
- `meru-migrate` - nuwa-app's migration Job: DNS and the namespace's Postgres.


## Changelog

### meru-baseline 0.1.0

- First release: the three policies above.

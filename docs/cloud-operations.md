# Operación cloud: disponibilidad, copias y costes

## Estado operativo

- GKE regional en `europe-southwest1`, con nodos repartidos entre las zonas `a` y `b`.
- Cliente A: dos réplicas mínimas, distribución entre nodos, HPA de 2 a 4 y `PodDisruptionBudget` de al menos una réplica disponible.
- Cliente B: una réplica; puede adoptar el mismo patrón cuando su carga lo requiera.
- Cloud SQL: instancia privada zonal. La aplicación es tolerante a la caída de un Pod, pero la base de datos no es HA hasta cambiar `availability_type` a `REGIONAL`.

## Monitorización

Cloud Logging recibe los logs de nodos y cargas de GKE. Cloud Monitoring ejecuta cada minuto comprobaciones HTTP a `/web/health` de ambos Odoo y crea una incidencia tras dos minutos sin respuesta.

No se añade un destinatario de alertas automáticamente. Para recibir correo, crea y valida un canal en Cloud Monitoring y añade su identificador en `terraform.tfvars`:

```hcl
alert_notification_channel_ids = ["projects/pec3-odoo-cloud-jca26/notificationChannels/IDENTIFICADOR"]
```

Comandos útiles:

```powershell
kubectl top pods -n odoo-multitenant
kubectl get hpa,pdb -n odoo-multitenant
kubectl get events -n odoo-multitenant --sort-by=.lastTimestamp
kubectl logs deployment/odoo-cliente-a -n odoo-multitenant --tail=100
```

## Copias de Cloud SQL

Cloud SQL conserva siete backups y siete días de recuperación puntual. Verificación:

```powershell
gcloud sql instances describe odoo-postgres --project pec3-odoo-cloud-jca26 --format="yaml(settings.backupConfiguration)"
gcloud sql backups list --instance odoo-postgres --project pec3-odoo-cloud-jca26
```

Para una restauración segura, primero restaura o clona hacia una instancia de recuperación, valida los datos y solo después planifica el cambio de producción. No se restaura directamente sobre la instancia activa.

## Copias de Filestore

Cada cliente tiene su propio Filestore de 100 GiB. Una copia se solicita con el script `scripts/New-FilestoreBackup.ps1`; el nombre de instancia y la zona se obtienen así:

```powershell
gcloud filestore instances list --project pec3-odoo-cloud-jca26 --location=europe-southwest1-a
gcloud filestore instances list --project pec3-odoo-cloud-jca26 --location=europe-southwest1-b
```

Ejemplo para una instancia Basic en la zona `europe-southwest1-a`:

```powershell
.\scripts\New-FilestoreBackup.ps1 `
  -Instance "NOMBRE_DE_INSTANCIA" `
  -FileShare "vol1" `
  -InstanceZone "europe-southwest1-a"
```

Las copias de Filestore son recursos facturables independientes. Antes de crear un backup completo de cada volumen, confirma que hay datos valiosos que proteger. La restauración se realiza a una instancia Filestore nueva; se monta en un Pod temporal y se validan los archivos antes de sustituir la ruta de producción.

## Terraform remoto

El estado Terraform se guarda en `gs://pec3-odoo-cloud-jca26-tfstate/odoo-cloud`, con control de versiones y acceso público bloqueado. El bucket se conserva aunque se destruya el entorno para no perder el historial de estado.

## Pausar o destruir

GKE no tiene una pausa completa equivalente a Docker Compose. Para dejar de facturar nodos, Cloud SQL y Filestore, desde `infra/terraform`:

```powershell
terraform plan -destroy
terraform destroy
```

Antes de destruir, guarda las copias necesarias. Los PVC de Filestore usan `Retain`, por lo que revisa y elimina manualmente los Filestore que ya no quieras conservar; de otro modo seguirán generando coste.

Para reconstruir el entorno posteriormente:

```powershell
terraform init
terraform apply
```

Después hay que reaplicar los manifiestos de `k8s/cloud/` y recrear los secretos de Secret Manager si se eliminaron fuera del estado Terraform.

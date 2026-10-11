param(
  [Parameter(Mandatory = $true)]
  [string]$Instance,

  [Parameter(Mandatory = $true)]
  [string]$FileShare,

  [Parameter(Mandatory = $true)]
  [string]$InstanceZone,

  [string]$ProjectId = "pec3-odoo-cloud-jca26",
  [string]$BackupRegion = "europe-southwest1"
)

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$backupName = "odoo-filestore-$timestamp"

gcloud filestore backups create $backupName `
  --instance=$Instance `
  --file-share=$FileShare `
  --instance-zone=$InstanceZone `
  --region=$BackupRegion `
  --description="Copia manual de Filestore para Odoo" `
  --project=$ProjectId

Write-Host "Copia solicitada: $backupName"

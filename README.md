# Odoo Cloud MultiTenant — MVP local

MVP local de una arquitectura multiempresa con dos clientes ficticios de Odoo Community, cada uno con su propia instancia Odoo, base de datos PostgreSQL, red Docker y volúmenes persistentes.

## Arquitectura

| Cliente | Odoo | PostgreSQL | Red | Volúmenes |
|---|---|---|---|---|
| Cliente A | http://localhost:8069 | Interno, puerto 5432 | `cliente_a_network` | `postgres_cliente_a`, `odoo_cliente_a`, `addons_cliente_a` |
| Cliente B | http://localhost:8070 | Interno, puerto 5432 | `cliente_b_network` | `postgres_cliente_b`, `odoo_cliente_b`, `addons_cliente_b` |

Los puertos PostgreSQL no se publican en Windows. Cada instancia Odoo solo puede comunicarse con la base de datos de su cliente mediante su red Docker privada.

## Requisitos

- Docker Desktop en ejecución.
- Docker Compose.
- Git.
- Navegador web.

## Configuración segura

No se deben versionar secretos. Los siguientes archivos están ignorados por Git:

- `.env`
- `config/*.conf`

Crea tus archivos locales a partir de las plantillas:

```powershell
Copy-Item .env.example .env
Copy-Item config\odoo-cliente-a.conf.example config\odoo-cliente-a.conf
Copy-Item config\odoo-cliente-b.conf.example config\odoo-cliente-b.conf
```

Define contraseñas fuertes y diferentes para ambos clientes. No compartas ni subas estos archivos.

## Inicio

Valida la configuración:

```powershell
docker compose config --quiet
```

Inicia los servicios:

```powershell
docker compose up -d
```

Comprueba su estado:

```powershell
docker compose ps
```

## Crear las bases de datos Odoo

1. Abre `http://localhost:8069/web/database/manager`.
2. Crea la base de datos del Cliente A con la contraseña maestra definida en `config/odoo-cliente-a.conf`.
3. Abre `http://localhost:8070/web/database/manager`.
4. Crea la base de datos del Cliente B con la contraseña maestra definida en `config/odoo-cliente-b.conf`.

Se recomienda usar nombres diferentes, por ejemplo:

- `cliente_a_operaciones`
- `cliente_b_operaciones`

## Validación de aislamiento

1. Crea un contacto de prueba en Cliente A.
2. Comprueba que no aparece en Cliente B.
3. Repite la prueba en sentido contrario.
4. Verifica los volúmenes persistentes:

```powershell
docker volume ls | Select-String "cliente_a|cliente_b"
```

## Operación

Detener los servicios sin borrar datos:

```powershell
docker compose stop
```

Reanudarlos:

```powershell
docker compose start
```

Ver registros:

```powershell
docker compose logs -f
```

Eliminar contenedores y redes, conservando volúmenes:

```powershell
docker compose down
```

> `docker compose down -v` también elimina los volúmenes persistentes y, con ellos, las bases de datos y archivos de Odoo. Úsalo únicamente cuando quieras reiniciar el entorno desde cero.

## Seguridad y despliegue cloud

El MVP local usa `.env` y archivos `.conf` ignorados por Git. En cloud, los secretos deben inyectarse desde un gestor de secretos del proveedor (por ejemplo, Secret Manager, Key Vault o Parameter Store) y nunca almacenarse en el repositorio, la imagen Docker o los registros.

## Kubernetes local

La carpeta `k8s/` contiene la versión declarativa de la arquitectura para Kubernetes. Compose y Kubernetes son entornos independientes: el primero mantiene el MVP local sencillo y el segundo permite practicar réplicas, recuperación de pods y autoescalado.

### Preparación

Con Kubernetes habilitado en Docker Desktop, crea el namespace y las copias privadas de los secretos:

```powershell
kubectl apply -f k8s\namespace.yaml
Copy-Item k8s\secrets\cliente-a.secret.example.yaml k8s\secrets\cliente-a.secret.yaml
Copy-Item k8s\secrets\cliente-b.secret.example.yaml k8s\secrets\cliente-b.secret.yaml
```

Edita las dos copias `.secret.yaml` con valores fuertes y privados; esos archivos están excluidos de Git. Después aplícalos y despliega los recursos:

```powershell
kubectl apply -f k8s\secrets\cliente-a.secret.yaml
kubectl apply -f k8s\secrets\cliente-b.secret.yaml
kubectl apply -f k8s\storage\postgres-pvc.yaml
kubectl apply -f k8s\storage\odoo-filestore-pvc.yaml
kubectl apply -f k8s\postgres\cliente-a.yaml
kubectl apply -f k8s\postgres\cliente-b.yaml
kubectl apply -f k8s\odoo\cliente-a.yaml
kubectl apply -f k8s\odoo\cliente-b.yaml
kubectl apply -f k8s\autoscaling\cliente-a-hpa.yaml
```

### Acceso local

Usa túneles temporales para abrir cada instancia sin exponerla públicamente:

```powershell
kubectl port-forward -n odoo-multitenant service/odoo-cliente-a 8081:8069
kubectl port-forward -n odoo-multitenant service/odoo-cliente-b 8082:8069
```

- Cliente A: `http://localhost:8081/web/login?db=cliente_a_k8s`
- Cliente B: `http://localhost:8082/web/login?db=cliente_b_k8s`

### Validación Kubernetes

```powershell
kubectl get pods,pvc -n odoo-multitenant
kubectl get hpa -n odoo-multitenant
kubectl top pods -n odoo-multitenant
```

Cliente A incluye dos réplicas y un `HorizontalPodAutoscaler` que puede aumentar hasta cuatro según CPU. Para pruebas locales de métricas, `k8s/metrics-server-local-patch.json` permite que Metrics Server consulte el kubelet de Docker Desktop. No debe trasladarse sin revisión a cloud, donde debe mantenerse la validación TLS.

### Límites del laboratorio local

El clúster local tiene un solo nodo y los PVC usan almacenamiento `ReadWriteOnce`. Las réplicas permiten practicar recuperación de pods y escalado, pero no tolerancia a la caída del equipo. Para cloud, Odoo requiere filestore compartido `ReadWriteMany` o almacenamiento de objetos, PostgreSQL administrado y un clúster con varios nodos para alta disponibilidad real.

## Estado del MVP

- Dos instancias independientes de Odoo 19 Community.
- Dos PostgreSQL 16 independientes.
- Dos redes Docker aisladas.
- Seis volúmenes persistentes independientes: base de datos, filestore y addons por cliente.
- Secretos locales excluidos de Git.
- Manifiestos Kubernetes para dos clientes, persistencia, comprobaciones de salud y autoescalado de Odoo Cliente A.

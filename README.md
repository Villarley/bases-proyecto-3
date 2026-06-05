# Planilla Obrera — Control de Asistencia (IC-4301 Bases de Datos I)

Sistema académico de **control de asistencia y planilla obrera**: registro de empleados, marcas de asistencia, cálculo de planilla y consultas vía procedimientos almacenados en SQL Server.

## Stack

- **Monorepo:** Turborepo + npm workspaces
- **Web:** Next.js 15 (App Router) — solo consume la API REST
- **API:** NestJS 11 — único punto de acceso a la base de datos
- **BD:** Microsoft SQL Server 2019 en Docker

## Requisitos

- Node.js 20+
- Docker (para SQL Server)
- Copiar `.env.example` a `.env` en la raíz del repo

## Puesta en marcha local

```bash
npm install
npm run db:up
```

Con el contenedor en marcha, aplicar el esquema y datos iniciales (cuando existan en el repo):

1. `database.sql`
2. `scripts/seed_catalogs.sql`
3. `scripts/triggers.sql`

Luego levantar las apps:

```bash
npm run dev
```

- Web: [http://localhost:3000](http://localhost:3000)
- API: [http://localhost:4000](http://localhost:4000) — `GET /` devuelve `{ status, db }`

## Scripts npm (raíz)

| Script      | Descripción                                      |
| ----------- | ------------------------------------------------ |
| `dev`       | Arranca web y API en modo desarrollo (Turbo)     |
| `build`     | Compila todos los workspaces                     |
| `lint`      | ESLint en todos los paquetes                     |
| `format`    | Prettier (`--write .`) en todo el monorepo       |
| `db:up`     | Levanta SQL Server con Docker Compose            |
| `db:down`   | Detiene y elimina el contenedor de la BD         |
| `db:logs`   | Sigue los logs del contenedor `planilla-obrera-mssql` |

## Estructura

```
apps/api     NestJS — acceso a SQL Server (mssql)
apps/web     Next.js — UI
packages/*   Tipos y config compartidos (sin acceso a BD)
db/docker/   docker-compose.yml
```

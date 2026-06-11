# Bitácora de trabajo - Control de Asistencia y Planilla Obrera

Proyecto IC-4301 Bases de Datos I - Prof. F. Quirós

---

## Sesión 1 - Modelo físico de la base de datos y catálogos

Fecha: sábado 7 de junio 2026

Hora de inicio: 2:00 pm

Hora de fin: 5:30 pm

Horas trabajadas: 3h 30m

### Descripción de avances

- **Modelo físico (`database.sql`)**: se definieron las 23 tablas del sistema, separadas en catálogos (TipoDocumentoIdentidad, Departamento, Puesto, TipoJornada, Feriado, TipoMovimiento, TipoDeduccion, TipoEvento, TipoUsuario), núcleo (Usuario, Empleado) y ciclo de planilla (MesPlanilla, SemanaPlanilla, PlanillaMesEmpleado, PlanillaSemanaEmpleado, DeduccionEmpleadoMes, Movimiento, MarcaAsistencia), más trazabilidad (BitacoraEvento, Error, DBError).

- **Trigger de deducciones obligatorias**: se implementó `trg_Empleado_AsignaDeduccionesObligatorias` (AFTER INSERT) para asociar automáticamente la deducción de ley (Caja, 10.67%) a todo empleado nuevo.

- **Carga de catálogos por XML**: se creó `catalogos.xml` y `seed_catalogs.sql`, que lo lee con `OPENROWSET(... SINGLE_BLOB)` y lo inserta respetando las llaves tal cual vienen, excepto Puesto.

- **Infraestructura**: se levantó SQL Server 2019 en Docker con `docker-compose.yml`, montando las carpetas de scripts y XML como volúmenes de solo lectura.

### Problemas encontrados

- El enunciado pide que las llaves de catálogo se inserten tal cual del XML, pero Puesto debe mapearse por nombre porque su Id es autoincremental y varía entre grupos.

- No estaba claro cómo modelar los acumuladores semanales y mensuales para no recalcular todo en cada consulta.

### Solución aplicada

- Se definió `dbo.Puesto` con `Id IDENTITY` y restricción `UNIQUE(Nombre)`, de modo que el mapeo se hace por nombre y el Id queda interno.

- Se separaron los acumuladores en `PlanillaSemanaEmpleado` y `PlanillaMesEmpleado`, con `DeduccionEmpleadoMes` para el detalle de deducciones por empleado por mes; así el cierre semanal solo incrementa contadores.

### Próximos pasos

- Escribir los procedimientos almacenados siguiendo el estándar de codificación del curso.

- Implementar el script de simulación que procesa el XML de operación.

- Preparar el catálogo de códigos de error en `dbo.Error`.

---

## Sesión 2 - Procedimientos almacenados y simulación de planilla

Fecha: lunes 9 de junio 2026

Hora de inicio: 7:00 pm

Hora de fin: 11:00 pm

Horas trabajadas: 4h

### Descripción de avances

- **Procedimientos almacenados (`scripts/sp/`)**: se escribieron seis scripts siguiendo el estándar del curso (mayúsculas, comas al inicio, prefijos `@in`/`@out`, `@outResultCode` en todos, CATCH que inserta en `dbo.DBError`, sin `SELECT *`, sin cursores, transacción al final): catálogo de errores, utilidades (bitácora y lectura de error), autenticación, CRUD de empleados, consultas de planilla y simulación.

- **Lógica de cálculo de horas**: en `spSim_ProcesarMarca` se calcula horas ordinarias, extra normales (×1.5) y extra dobles (×2.0 en domingo o feriado), pagando solo horas completas y partiendo una misma marca en hasta tres movimientos.

- **Cierre semanal**: se aplica la deducción porcentual sobre el salario bruto y las fijas dividiendo el monto mensual entre la cantidad de jueves del mes; todo con una sola transacción de BD por empleado, según la regla del enunciado.

- **Runner de simulación**: `05_simulacion_run.sql` carga `Operaciones.xml` y ejecuta toda la corrida de varios meses.

### Problemas encontrados

- El XML oficial de operación referencia puestos que no existían en el catálogo (Cajero, Conductor), por lo que los empleados fallaban al insertarse con código 50006.

- El XML usa el nombre "Ahorro Asociacion Solidarista" para la deducción, distinto al que tenía el catálogo.

- El XML contiene una desasociación de una deducción que el empleado nunca tuvo, lo que detenía la simulación a mitad de la corrida.

- Al hacer `RESEED` de identidades en 0, el primer Usuario quedaba con Id = 0.

### Solución aplicada

- Se agregaron los puestos Cajero y Conductor al catálogo y se renombró la deducción para que coincida exactamente con el XML oficial (el XML manda).

- Se hicieron los orquestadores `spSim_ProcesarFechaOperacion` y `spSimulacion_Ejecutar` tolerantes a códigos de rechazo benignos: registran y continúan, mientras que los errores reales de plataforma sí quedan en `dbo.DBError`.

- Se cambió el `RESEED` de identidades a 1.

- Se verificó la corrida completa: 3 empleados, 60 marcas, 84 movimientos, 4 semanas, 1 mes, 0 errores; el caso del feriado 1 de mayo paga correctamente 8 horas ordinarias y 2 horas extra dobles.

### Próximos pasos

- Construir la capa lógica (API) que exponga los procedimientos almacenados.

- Validar el mapeo de códigos de error a respuestas de la aplicación.

- Iniciar los portales web de administrador y empleado.

---

## Sesión 3 - Capa lógica: API REST sobre los procedimientos

Fecha: martes 10 de junio 2026

Hora de inicio: 8:00 pm

Hora de fin: 10:30 pm

Horas trabajadas: 2h 30m

### Descripción de avances

- **API en NestJS (`apps/api`)**: se extendió `DatabaseService` con un método tipado por cada procedimiento almacenado, de modo que todo acceso a la BD pasa por un SP (no hay SQL incrustado en la capa lógica).

- **Módulos por dominio**: auth (`/auth/login`, `/auth/logout`), empleados (`/empleados` con CRUD por documento, impersonar y regresar a administrador), planilla (consultas semanal y mensual con detalle de deducciones y de marcas) y catálogos.

- **Trazabilidad y errores**: se creó el decorador `@ClientIp()` para registrar la IP en la bitácora y un helper que traduce el `@outResultCode` del SP al código HTTP correspondiente, tomando el mensaje desde `spError_ObtenerPorCodigo`.

- **Pruebas en vivo**: se probó login de administrador y empleado, login fallido (401), listar y filtrar empleados, crear–iniciar sesión–editar–eliminar empleado, documento duplicado (422) y las consultas de planilla, todas devolviendo cifras correctas.

### Problemas encontrados

- Se requería identificar al usuario para la bitácora sin montar todavía un esquema de autenticación con tokens.

- El pool de `mssql` rechazaba la conexión al contenedor por el certificado del servidor.

### Solución aplicada

- Para mantener el proyecto simple se optó por que el frontend reenvíe el `idUsuario` obtenido en el login; queda documentado como punto a reforzar con sesión/token si se pide.

- Se configuró el pool con `encrypt` y `trustServerCertificate` para el certificado autofirmado del contenedor de desarrollo.

### Próximos pasos

- Implementar el portal web de administrador (listar/editar empleados, impersonar).

- Implementar el portal web de empleado (planilla semanal y mensual).

- Redactar la documentación final y dejar lista la corrida completa de la simulación para la entrega del 13 de junio.

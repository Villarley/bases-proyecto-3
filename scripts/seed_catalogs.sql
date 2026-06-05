SET NOCOUNT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

USE planilla_obrera;
GO

DECLARE @xml XML;

SELECT
    @xml = CAST(x.BulkColumn AS XML)
FROM
    OPENROWSET(BULK N'/seed/catalogos.xml', SINGLE_BLOB) AS x; -- /seed montado en docker-compose.yml

DELETE FROM dbo.TipoDeduccion;
DELETE FROM dbo.TipoMovimiento;
DELETE FROM dbo.Feriado;
DELETE FROM dbo.TipoJornada;
DELETE FROM dbo.Puesto;
DELETE FROM dbo.Departamento;
DELETE FROM dbo.TipoDocumentoIdentidad;
DELETE FROM dbo.TipoEvento;
DELETE FROM dbo.Usuario;
DELETE FROM dbo.TipoUsuario;

DBCC CHECKIDENT (N'dbo.Puesto', RESEED, 0);
DBCC CHECKIDENT (N'dbo.Usuario', RESEED, 0);

INSERT INTO dbo.TipoDocumentoIdentidad
(
    Id
    , Nombre
)
SELECT
    T.c.value(N'@Id', N'INT')
    , T.c.value(N'@Nombre', N'NVARCHAR(100)')
FROM
    @xml.nodes(N'/Catalogos/TiposDocumentoIdentidad/TipoDocumentoIdentidad') AS T (c);

INSERT INTO dbo.Departamento
(
    Id
    , Nombre
)
SELECT
    T.c.value(N'@Id', N'INT')
    , T.c.value(N'@Nombre', N'NVARCHAR(150)')
FROM
    @xml.nodes(N'/Catalogos/Departamentos/Departamento') AS T (c);

INSERT INTO dbo.Puesto
(
    Nombre
    , SalarioXHora
)
SELECT
    T.c.value(N'@Nombre', N'NVARCHAR(200)')
    , T.c.value(N'@SalarioXHora', N'DECIMAL(12, 2)')
FROM
    @xml.nodes(N'/Catalogos/Puestos/Puesto') AS T (c);

INSERT INTO dbo.TipoJornada
(
    Id
    , Nombre
    , HoraInicio
    , HoraFin
    , DuracionHoras
    , CruzaMedianoche
)
SELECT
    T.c.value(N'@Id', N'INT')
    , T.c.value(N'@Nombre', N'NVARCHAR(50)')
    , T.c.value(N'@HoraInicio', N'TIME(0)')
    , T.c.value(N'@HoraFin', N'TIME(0)')
    , T.c.value(N'@DuracionHoras', N'INT')
    , T.c.value(N'@CruzaMedianoche', N'BIT')
FROM
    @xml.nodes(N'/Catalogos/TiposJornada/TipoJornada') AS T (c);

INSERT INTO dbo.Feriado
(
    Id
    , Nombre
    , Fecha
)
SELECT
    T.c.value(N'@Id', N'INT')
    , T.c.value(N'@Nombre', N'NVARCHAR(150)')
    , T.c.value(N'@Fecha', N'DATE')
FROM
    @xml.nodes(N'/Catalogos/Feriados/Feriado') AS T (c);

INSERT INTO dbo.TipoMovimiento
(
    Id
    , Nombre
    , Accion
)
SELECT
    T.c.value(N'@Id', N'INT')
    , T.c.value(N'@Nombre', N'NVARCHAR(150)')
    , T.c.value(N'@Accion', N'CHAR(1)')
FROM
    @xml.nodes(N'/Catalogos/TiposMovimiento/TipoMovimiento') AS T (c);

INSERT INTO dbo.TipoDeduccion
(
    Id
    , Nombre
    , EsObligatorio
    , EsPorcentual
    , ValorPorDefecto
    , IdTipoMovimiento
)
SELECT
    T.c.value(N'@Id', N'INT')
    , T.c.value(N'@Nombre', N'NVARCHAR(150)')
    , T.c.value(N'@EsObligatorio', N'BIT')
    , T.c.value(N'@EsPorcentual', N'BIT')
    , T.c.value(N'@ValorPorDefecto', N'DECIMAL(12, 4)')
    , T.c.value(N'@IdTipoMovimiento', N'INT')
FROM
    @xml.nodes(N'/Catalogos/TiposDeduccion/TipoDeduccion') AS T (c);

INSERT INTO dbo.TipoUsuario
(
    Id
    , Nombre
)
SELECT
    T.c.value(N'@Id', N'INT')
    , T.c.value(N'@Nombre', N'NVARCHAR(50)')
FROM
    @xml.nodes(N'/Catalogos/TiposUsuario/TipoUsuario') AS T (c);

INSERT INTO dbo.Usuario
(
    Username
    , Password
    , IdTipoUsuario
)
SELECT
    T.c.value(N'@Username', N'NVARCHAR(100)')
    , T.c.value(N'@Password', N'NVARCHAR(256)')
    , tu.Id
FROM
    @xml.nodes(N'/Catalogos/Usuarios/Usuario') AS T (c)
INNER JOIN dbo.TipoUsuario AS tu
    ON (tu.Nombre = T.c.value(N'@TipoUsuario', N'NVARCHAR(50)'));

INSERT INTO dbo.TipoEvento
(
    Id
    , Nombre
)
SELECT
    T.c.value(N'@Id', N'INT')
    , T.c.value(N'@Nombre', N'NVARCHAR(150)')
FROM
    @xml.nodes(N'/Catalogos/TiposEvento/TipoEvento') AS T (c);
GO

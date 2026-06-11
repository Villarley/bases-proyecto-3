SET NOCOUNT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

USE planilla_obrera;
GO

DECLARE @xml XML;
DECLARE @rc INT;
DECLARE @desc NVARCHAR(1000);
DECLARE @errorRc INT;

SELECT
    @xml = CAST(x.BulkColumn AS XML)
FROM
    OPENROWSET(BULK N'/seed/Operaciones.xml', SINGLE_BLOB) AS x; -- /seed montado en docker-compose.yml

EXEC dbo.spSimulacion_Ejecutar
    @inXml = @xml
    , @inIP = N'127.0.0.1'
    , @outResultCode = @rc OUTPUT;

IF (@rc = 0)
BEGIN
    PRINT N'Simulacion completada correctamente.';
END
ELSE
BEGIN
    EXEC dbo.spError_ObtenerPorCodigo
        @inCodigo = @rc
        , @outDescripcion = @desc OUTPUT
        , @outResultCode = @errorRc OUTPUT;

    PRINT CONCAT(N'Simulacion termino con codigo ', @rc, N': ', @desc);
END;

SELECT
    N'Empleado' AS Entidad
    , COUNT(1) AS Cantidad
FROM
    dbo.Empleado AS e
UNION ALL
SELECT
    N'MarcaAsistencia'
    , COUNT(1)
FROM
    dbo.MarcaAsistencia AS ma
UNION ALL
SELECT
    N'Movimiento'
    , COUNT(1)
FROM
    dbo.Movimiento AS m
UNION ALL
SELECT
    N'SemanaPlanilla'
    , COUNT(1)
FROM
    dbo.SemanaPlanilla AS sp
UNION ALL
SELECT
    N'MesPlanilla'
    , COUNT(1)
FROM
    dbo.MesPlanilla AS mp;

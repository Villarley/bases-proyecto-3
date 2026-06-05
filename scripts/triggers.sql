SET NOCOUNT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

USE planilla_obrera;
GO

CREATE OR ALTER TRIGGER dbo.trg_Empleado_AsignaDeduccionesObligatorias
ON dbo.Empleado
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    -- Al insertar un empleado, este debe asociarse automaticamente con las deducciones obligatorias, a traves de un trigger.

    INSERT INTO dbo.EmpleadoDeduccion
    (
        IdEmpleado
        , IdTipoDeduccion
        , PorcentajeOMonto
        , FechaInicioVigencia
        , EsActivo
    )
    SELECT
        i.Id
        , td.Id
        , td.ValorPorDefecto
        , i.FechaIngreso
        , CAST(1 AS BIT)
    FROM
        inserted AS i
    CROSS JOIN dbo.TipoDeduccion AS td
    WHERE
        (td.EsObligatorio = 1)
        AND NOT EXISTS (
            SELECT
                1
            FROM
                dbo.EmpleadoDeduccion AS ed
            WHERE
                (ed.IdEmpleado = i.Id)
                AND (ed.IdTipoDeduccion = td.Id)
                AND (ed.EsActivo = 1)
        );
END;
GO

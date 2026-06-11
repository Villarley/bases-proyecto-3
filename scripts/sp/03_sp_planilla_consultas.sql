SET NOCOUNT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

USE planilla_obrera;
GO

CREATE OR ALTER PROCEDURE dbo.spPlanilla_ConsultarSemanal
    @inIdUsuario INT
    , @inIP NVARCHAR(45)
    , @inValorDocumentoIdentidad NVARCHAR(50)
    , @inCantidadSemanas INT
    , @outResultCode INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    SET @outResultCode = 50008;

    DECLARE @IdEmpleado INT;
    DECLARE @CantidadSemanas INT;
    DECLARE @FechaInicioMin DATE;
    DECLARE @FechaFinMax DATE;
    DECLARE @Parametros NVARCHAR(MAX);
    DECLARE @BitacoraResultCode INT;

    BEGIN TRY
        SELECT
            @IdEmpleado = e.Id
        FROM
            dbo.Empleado AS e
        WHERE
            (e.ValorDocumentoIdentidad = @inValorDocumentoIdentidad)
            AND (e.EsActivo = 1);

        IF (@IdEmpleado IS NULL)
        BEGIN
            SET @outResultCode = 50003;

            RETURN;
        END;

        SET @CantidadSemanas = ISNULL(@inCantidadSemanas, 8);

        SELECT
            @FechaInicioMin = MIN(sub.FechaInicioSemana)
            , @FechaFinMax = MAX(sub.FechaFinSemana)
        FROM
        (
            SELECT TOP (@CantidadSemanas)
                sp.FechaInicio AS FechaInicioSemana
                , sp.FechaFin AS FechaFinSemana
            FROM
                dbo.PlanillaSemanaEmpleado AS pse
            INNER JOIN
                dbo.SemanaPlanilla AS sp
                ON (sp.Id = pse.IdSemanaPlanilla)
            WHERE
                (pse.IdEmpleado = @IdEmpleado)
            ORDER BY
                sp.FechaInicio DESC
        ) AS sub;

        SELECT TOP (@CantidadSemanas)
            sp.FechaInicio AS FechaInicioSemana
            , sp.FechaFin AS FechaFinSemana
            , pse.SalarioBruto
            , pse.TotalDeducciones
            , pse.SalarioNeto
            , pse.CantidadHorasOrdinarias
            , pse.CantidadHorasExtraNormales
            , pse.CantidadHorasExtraDobles
        FROM
            dbo.PlanillaSemanaEmpleado AS pse
        INNER JOIN
            dbo.SemanaPlanilla AS sp
            ON (sp.Id = pse.IdSemanaPlanilla)
        WHERE
            (pse.IdEmpleado = @IdEmpleado)
        ORDER BY
            sp.FechaInicio DESC;

        SET @Parametros =
            N'{"idEmpleado":'
            + CAST(@IdEmpleado AS NVARCHAR(20))
            + N',"fechaInicio":'
            + CASE
                WHEN (@FechaInicioMin IS NULL) THEN N'null'
                ELSE
                    N'"'
                    + CONVERT(NVARCHAR(10), @FechaInicioMin, 23)
                    + N'"'
            END
            + N',"fechaFin":'
            + CASE
                WHEN (@FechaFinMax IS NULL) THEN N'null'
                ELSE
                    N'"'
                    + CONVERT(NVARCHAR(10), @FechaFinMax, 23)
                    + N'"'
            END
            + N'}';

        EXEC dbo.spBitacora_RegistrarEvento
            @inIdTipoEvento = 9
            , @inIdUsuario = @inIdUsuario
            , @inIP = @inIP
            , @inParametros = @Parametros
            , @inValoresAntes = NULL
            , @inValoresDespues = NULL
            , @outResultCode = @BitacoraResultCode OUTPUT;

        SET @outResultCode = 0;
    END TRY
    BEGIN CATCH
        IF (@@TRANCOUNT > 0)
        BEGIN
            ROLLBACK TRANSACTION;
        END;

        INSERT INTO dbo.DBError
        (
            UserName
            , Number
            , State
            , Severity
            , Line
            , [Procedure]
            , [Message]
            , [DateTime]
        )
        VALUES
        (
            SUSER_SNAME()
            , ERROR_NUMBER()
            , ERROR_STATE()
            , ERROR_SEVERITY()
            , ERROR_LINE()
            , ERROR_PROCEDURE()
            , ERROR_MESSAGE()
            , SYSDATETIME()
        );

        SET @outResultCode = 50008;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE dbo.spPlanilla_ConsultarDeduccionesSemana
    @inIdUsuario INT
    , @inIP NVARCHAR(45)
    , @inValorDocumentoIdentidad NVARCHAR(50)
    , @inFechaInicioSemana DATE
    , @outResultCode INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    SET @outResultCode = 50008;

    DECLARE @IdEmpleado INT;
    DECLARE @IdSemanaPlanilla INT;
    DECLARE @FechaInicioSemana DATE;
    DECLARE @FechaFinSemana DATE;
    DECLARE @Parametros NVARCHAR(MAX);
    DECLARE @BitacoraResultCode INT;

    BEGIN TRY
        SELECT
            @IdEmpleado = e.Id
        FROM
            dbo.Empleado AS e
        WHERE
            (e.ValorDocumentoIdentidad = @inValorDocumentoIdentidad)
            AND (e.EsActivo = 1);

        IF (@IdEmpleado IS NULL)
        BEGIN
            SET @outResultCode = 50003;

            RETURN;
        END;

        SELECT
            @IdSemanaPlanilla = sp.Id
            , @FechaInicioSemana = sp.FechaInicio
            , @FechaFinSemana = sp.FechaFin
        FROM
            dbo.SemanaPlanilla AS sp
        WHERE
            (sp.FechaInicio = @inFechaInicioSemana);

        IF (@IdSemanaPlanilla IS NULL)
        BEGIN
            SET @outResultCode = 50012;

            RETURN;
        END;

        SELECT
            td.Nombre AS NombreDeduccion
            , CASE
                WHEN (td.EsPorcentual = 1) THEN ed.PorcentajeOMonto
                ELSE NULL
            END AS PorcentajeAplicado
            , m.Monto AS MontoDeduccion
        FROM
            dbo.Movimiento AS m
        INNER JOIN
            dbo.PlanillaSemanaEmpleado AS pse
            ON (pse.Id = m.IdPlanillaSemanaEmpleado)
        INNER JOIN
            dbo.TipoDeduccion AS td
            ON (td.Id = m.IdTipoDeduccion)
        OUTER APPLY (
            SELECT
                TOP (1)
                edx.PorcentajeOMonto
            FROM
                dbo.EmpleadoDeduccion AS edx
            WHERE
                (edx.IdEmpleado = @IdEmpleado)
                AND (edx.IdTipoDeduccion = m.IdTipoDeduccion)
            ORDER BY
                edx.EsActivo DESC
                , edx.Id DESC
        ) AS ed
        WHERE
            (m.IdEmpleado = @IdEmpleado)
            AND (m.IdTipoDeduccion IS NOT NULL)
            AND (pse.IdSemanaPlanilla = @IdSemanaPlanilla);

        SET @Parametros =
            N'{"idEmpleado":'
            + CAST(@IdEmpleado AS NVARCHAR(20))
            + N',"fechaInicio":"'
            + CONVERT(NVARCHAR(10), @FechaInicioSemana, 23)
            + N'","fechaFin":"'
            + CONVERT(NVARCHAR(10), @FechaFinSemana, 23)
            + N'"}';

        EXEC dbo.spBitacora_RegistrarEvento
            @inIdTipoEvento = 9
            , @inIdUsuario = @inIdUsuario
            , @inIP = @inIP
            , @inParametros = @Parametros
            , @inValoresAntes = NULL
            , @inValoresDespues = NULL
            , @outResultCode = @BitacoraResultCode OUTPUT;

        SET @outResultCode = 0;
    END TRY
    BEGIN CATCH
        IF (@@TRANCOUNT > 0)
        BEGIN
            ROLLBACK TRANSACTION;
        END;

        INSERT INTO dbo.DBError
        (
            UserName
            , Number
            , State
            , Severity
            , Line
            , [Procedure]
            , [Message]
            , [DateTime]
        )
        VALUES
        (
            SUSER_SNAME()
            , ERROR_NUMBER()
            , ERROR_STATE()
            , ERROR_SEVERITY()
            , ERROR_LINE()
            , ERROR_PROCEDURE()
            , ERROR_MESSAGE()
            , SYSDATETIME()
        );

        SET @outResultCode = 50008;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE dbo.spPlanilla_ConsultarDetalleSemana
    @inIdUsuario INT
    , @inIP NVARCHAR(45)
    , @inValorDocumentoIdentidad NVARCHAR(50)
    , @inFechaInicioSemana DATE
    , @outResultCode INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    SET @outResultCode = 50008;

    DECLARE @IdEmpleado INT;
    DECLARE @FechaInicioSemana DATE;
    DECLARE @FechaFinSemana DATE;
    DECLARE @Parametros NVARCHAR(MAX);
    DECLARE @BitacoraResultCode INT;

    BEGIN TRY
        SELECT
            @IdEmpleado = e.Id
        FROM
            dbo.Empleado AS e
        WHERE
            (e.ValorDocumentoIdentidad = @inValorDocumentoIdentidad)
            AND (e.EsActivo = 1);

        IF (@IdEmpleado IS NULL)
        BEGIN
            SET @outResultCode = 50003;

            RETURN;
        END;

        SELECT
            @FechaInicioSemana = sp.FechaInicio
            , @FechaFinSemana = sp.FechaFin
        FROM
            dbo.SemanaPlanilla AS sp
        WHERE
            (sp.FechaInicio = @inFechaInicioSemana);

        IF (@FechaInicioSemana IS NULL)
        BEGIN
            SET @outResultCode = 50012;

            RETURN;
        END;

        SELECT
            ma.Fecha
            , ma.HoraEntrada
            , ma.HoraSalida
            , ISNULL(
                SUM(
                    CASE
                        WHEN (m.IdTipoMovimiento = 1) THEN m.CantidadHoras
                        ELSE 0
                    END
                )
                , 0
            ) AS HorasOrdinarias
            , ISNULL(
                SUM(
                    CASE
                        WHEN (m.IdTipoMovimiento = 1) THEN m.Monto
                        ELSE 0
                    END
                )
                , 0
            ) AS MontoOrdinario
            , ISNULL(
                SUM(
                    CASE
                        WHEN (m.IdTipoMovimiento = 2) THEN m.CantidadHoras
                        ELSE 0
                    END
                )
                , 0
            ) AS HorasExtraNormales
            , ISNULL(
                SUM(
                    CASE
                        WHEN (m.IdTipoMovimiento = 2) THEN m.Monto
                        ELSE 0
                    END
                )
                , 0
            ) AS MontoExtraNormal
            , ISNULL(
                SUM(
                    CASE
                        WHEN (m.IdTipoMovimiento = 3) THEN m.CantidadHoras
                        ELSE 0
                    END
                )
                , 0
            ) AS HorasExtraDobles
            , ISNULL(
                SUM(
                    CASE
                        WHEN (m.IdTipoMovimiento = 3) THEN m.Monto
                        ELSE 0
                    END
                )
                , 0
            ) AS MontoExtraDoble
        FROM
            dbo.MarcaAsistencia AS ma
        LEFT JOIN
            dbo.Movimiento AS m
            ON (m.IdEmpleado = ma.IdEmpleado)
            AND (m.Fecha = ma.Fecha)
            AND (m.IdTipoMovimiento IN (1, 2, 3))
        WHERE
            (ma.IdEmpleado = @IdEmpleado)
            AND (ma.Fecha BETWEEN @FechaInicioSemana AND @FechaFinSemana)
        GROUP BY
            ma.Fecha
            , ma.HoraEntrada
            , ma.HoraSalida
        ORDER BY
            ma.Fecha ASC;

        SET @Parametros =
            N'{"idEmpleado":'
            + CAST(@IdEmpleado AS NVARCHAR(20))
            + N',"fechaInicio":"'
            + CONVERT(NVARCHAR(10), @FechaInicioSemana, 23)
            + N'","fechaFin":"'
            + CONVERT(NVARCHAR(10), @FechaFinSemana, 23)
            + N'"}';

        EXEC dbo.spBitacora_RegistrarEvento
            @inIdTipoEvento = 9
            , @inIdUsuario = @inIdUsuario
            , @inIP = @inIP
            , @inParametros = @Parametros
            , @inValoresAntes = NULL
            , @inValoresDespues = NULL
            , @outResultCode = @BitacoraResultCode OUTPUT;

        SET @outResultCode = 0;
    END TRY
    BEGIN CATCH
        IF (@@TRANCOUNT > 0)
        BEGIN
            ROLLBACK TRANSACTION;
        END;

        INSERT INTO dbo.DBError
        (
            UserName
            , Number
            , State
            , Severity
            , Line
            , [Procedure]
            , [Message]
            , [DateTime]
        )
        VALUES
        (
            SUSER_SNAME()
            , ERROR_NUMBER()
            , ERROR_STATE()
            , ERROR_SEVERITY()
            , ERROR_LINE()
            , ERROR_PROCEDURE()
            , ERROR_MESSAGE()
            , SYSDATETIME()
        );

        SET @outResultCode = 50008;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE dbo.spPlanilla_ConsultarMensual
    @inIdUsuario INT
    , @inIP NVARCHAR(45)
    , @inValorDocumentoIdentidad NVARCHAR(50)
    , @inCantidadMeses INT
    , @outResultCode INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    SET @outResultCode = 50008;

    DECLARE @IdEmpleado INT;
    DECLARE @CantidadMeses INT;
    DECLARE @FechaInicioMin DATE;
    DECLARE @FechaFinMax DATE;
    DECLARE @Parametros NVARCHAR(MAX);
    DECLARE @BitacoraResultCode INT;

    BEGIN TRY
        SELECT
            @IdEmpleado = e.Id
        FROM
            dbo.Empleado AS e
        WHERE
            (e.ValorDocumentoIdentidad = @inValorDocumentoIdentidad)
            AND (e.EsActivo = 1);

        IF (@IdEmpleado IS NULL)
        BEGIN
            SET @outResultCode = 50003;

            RETURN;
        END;

        SET @CantidadMeses = ISNULL(@inCantidadMeses, 6);

        SELECT
            @FechaInicioMin = MIN(sub.FechaInicio)
            , @FechaFinMax = MAX(sub.FechaFin)
        FROM
        (
            SELECT TOP (@CantidadMeses)
                mp.FechaInicio
                , mp.FechaFin
            FROM
                dbo.PlanillaMesEmpleado AS pme
            INNER JOIN
                dbo.MesPlanilla AS mp
                ON (mp.Id = pme.IdMesPlanilla)
            WHERE
                (pme.IdEmpleado = @IdEmpleado)
            ORDER BY
                mp.FechaInicio DESC
        ) AS sub;

        SELECT TOP (@CantidadMeses)
            mp.Anio
            , mp.Mes
            , mp.FechaInicio
            , mp.FechaFin
            , pme.SalarioBrutoMensual
            , pme.TotalDeduccionesMensual
            , pme.SalarioNetoMensual
        FROM
            dbo.PlanillaMesEmpleado AS pme
        INNER JOIN
            dbo.MesPlanilla AS mp
            ON (mp.Id = pme.IdMesPlanilla)
        WHERE
            (pme.IdEmpleado = @IdEmpleado)
        ORDER BY
            mp.FechaInicio DESC;

        SET @Parametros =
            N'{"idEmpleado":'
            + CAST(@IdEmpleado AS NVARCHAR(20))
            + N',"fechaInicio":'
            + CASE
                WHEN (@FechaInicioMin IS NULL) THEN N'null'
                ELSE
                    N'"'
                    + CONVERT(NVARCHAR(10), @FechaInicioMin, 23)
                    + N'"'
            END
            + N',"fechaFin":'
            + CASE
                WHEN (@FechaFinMax IS NULL) THEN N'null'
                ELSE
                    N'"'
                    + CONVERT(NVARCHAR(10), @FechaFinMax, 23)
                    + N'"'
            END
            + N'}';

        EXEC dbo.spBitacora_RegistrarEvento
            @inIdTipoEvento = 10
            , @inIdUsuario = @inIdUsuario
            , @inIP = @inIP
            , @inParametros = @Parametros
            , @inValoresAntes = NULL
            , @inValoresDespues = NULL
            , @outResultCode = @BitacoraResultCode OUTPUT;

        SET @outResultCode = 0;
    END TRY
    BEGIN CATCH
        IF (@@TRANCOUNT > 0)
        BEGIN
            ROLLBACK TRANSACTION;
        END;

        INSERT INTO dbo.DBError
        (
            UserName
            , Number
            , State
            , Severity
            , Line
            , [Procedure]
            , [Message]
            , [DateTime]
        )
        VALUES
        (
            SUSER_SNAME()
            , ERROR_NUMBER()
            , ERROR_STATE()
            , ERROR_SEVERITY()
            , ERROR_LINE()
            , ERROR_PROCEDURE()
            , ERROR_MESSAGE()
            , SYSDATETIME()
        );

        SET @outResultCode = 50008;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE dbo.spPlanilla_ConsultarDeduccionesMes
    @inIdUsuario INT
    , @inIP NVARCHAR(45)
    , @inValorDocumentoIdentidad NVARCHAR(50)
    , @inAnio INT
    , @inMes INT
    , @outResultCode INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    SET @outResultCode = 50008;

    DECLARE @IdEmpleado INT;
    DECLARE @IdMesPlanilla INT;
    DECLARE @FechaInicioMes DATE;
    DECLARE @FechaFinMes DATE;
    DECLARE @Parametros NVARCHAR(MAX);
    DECLARE @BitacoraResultCode INT;

    BEGIN TRY
        SELECT
            @IdEmpleado = e.Id
        FROM
            dbo.Empleado AS e
        WHERE
            (e.ValorDocumentoIdentidad = @inValorDocumentoIdentidad)
            AND (e.EsActivo = 1);

        IF (@IdEmpleado IS NULL)
        BEGIN
            SET @outResultCode = 50003;

            RETURN;
        END;

        SELECT
            @IdMesPlanilla = mp.Id
            , @FechaInicioMes = mp.FechaInicio
            , @FechaFinMes = mp.FechaFin
        FROM
            dbo.MesPlanilla AS mp
        WHERE
            (mp.Anio = @inAnio)
            AND (mp.Mes = @inMes);

        IF (@IdMesPlanilla IS NULL)
        BEGIN
            SET @outResultCode = 50013;

            RETURN;
        END;

        SELECT
            td.Nombre AS NombreDeduccion
            , dem.PorcentajeAplicado
            , dem.MontoAcumulado AS MontoDeduccion
        FROM
            dbo.DeduccionEmpleadoMes AS dem
        INNER JOIN
            dbo.PlanillaMesEmpleado AS pme
            ON (pme.Id = dem.IdPlanillaMesEmpleado)
        INNER JOIN
            dbo.TipoDeduccion AS td
            ON (td.Id = dem.IdTipoDeduccion)
        WHERE
            (pme.IdMesPlanilla = @IdMesPlanilla)
            AND (pme.IdEmpleado = @IdEmpleado);

        SET @Parametros =
            N'{"idEmpleado":'
            + CAST(@IdEmpleado AS NVARCHAR(20))
            + N',"fechaInicio":"'
            + CONVERT(NVARCHAR(10), @FechaInicioMes, 23)
            + N'","fechaFin":"'
            + CONVERT(NVARCHAR(10), @FechaFinMes, 23)
            + N'"}';

        EXEC dbo.spBitacora_RegistrarEvento
            @inIdTipoEvento = 10
            , @inIdUsuario = @inIdUsuario
            , @inIP = @inIP
            , @inParametros = @Parametros
            , @inValoresAntes = NULL
            , @inValoresDespues = NULL
            , @outResultCode = @BitacoraResultCode OUTPUT;

        SET @outResultCode = 0;
    END TRY
    BEGIN CATCH
        IF (@@TRANCOUNT > 0)
        BEGIN
            ROLLBACK TRANSACTION;
        END;

        INSERT INTO dbo.DBError
        (
            UserName
            , Number
            , State
            , Severity
            , Line
            , [Procedure]
            , [Message]
            , [DateTime]
        )
        VALUES
        (
            SUSER_SNAME()
            , ERROR_NUMBER()
            , ERROR_STATE()
            , ERROR_SEVERITY()
            , ERROR_LINE()
            , ERROR_PROCEDURE()
            , ERROR_MESSAGE()
            , SYSDATETIME()
        );

        SET @outResultCode = 50008;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE dbo.spCatalogo_ListarPuestos
    @outResultCode INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    SET @outResultCode = 50008;

    BEGIN TRY
        SELECT
            p.Id
            , p.Nombre
            , p.SalarioXHora
        FROM
            dbo.Puesto AS p
        ORDER BY
            p.Nombre ASC;

        SET @outResultCode = 0;
    END TRY
    BEGIN CATCH
        IF (@@TRANCOUNT > 0)
        BEGIN
            ROLLBACK TRANSACTION;
        END;

        INSERT INTO dbo.DBError
        (
            UserName
            , Number
            , State
            , Severity
            , Line
            , [Procedure]
            , [Message]
            , [DateTime]
        )
        VALUES
        (
            SUSER_SNAME()
            , ERROR_NUMBER()
            , ERROR_STATE()
            , ERROR_SEVERITY()
            , ERROR_LINE()
            , ERROR_PROCEDURE()
            , ERROR_MESSAGE()
            , SYSDATETIME()
        );

        SET @outResultCode = 50008;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE dbo.spCatalogo_ListarDepartamentos
    @outResultCode INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    SET @outResultCode = 50008;

    BEGIN TRY
        SELECT
            d.Id
            , d.Nombre
        FROM
            dbo.Departamento AS d
        ORDER BY
            d.Nombre ASC;

        SET @outResultCode = 0;
    END TRY
    BEGIN CATCH
        IF (@@TRANCOUNT > 0)
        BEGIN
            ROLLBACK TRANSACTION;
        END;

        INSERT INTO dbo.DBError
        (
            UserName
            , Number
            , State
            , Severity
            , Line
            , [Procedure]
            , [Message]
            , [DateTime]
        )
        VALUES
        (
            SUSER_SNAME()
            , ERROR_NUMBER()
            , ERROR_STATE()
            , ERROR_SEVERITY()
            , ERROR_LINE()
            , ERROR_PROCEDURE()
            , ERROR_MESSAGE()
            , SYSDATETIME()
        );

        SET @outResultCode = 50008;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE dbo.spCatalogo_ListarTiposDocumento
    @outResultCode INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    SET @outResultCode = 50008;

    BEGIN TRY
        SELECT
            t.Id
            , t.Nombre
        FROM
            dbo.TipoDocumentoIdentidad AS t
        ORDER BY
            t.Nombre ASC;

        SET @outResultCode = 0;
    END TRY
    BEGIN CATCH
        IF (@@TRANCOUNT > 0)
        BEGIN
            ROLLBACK TRANSACTION;
        END;

        INSERT INTO dbo.DBError
        (
            UserName
            , Number
            , State
            , Severity
            , Line
            , [Procedure]
            , [Message]
            , [DateTime]
        )
        VALUES
        (
            SUSER_SNAME()
            , ERROR_NUMBER()
            , ERROR_STATE()
            , ERROR_SEVERITY()
            , ERROR_LINE()
            , ERROR_PROCEDURE()
            , ERROR_MESSAGE()
            , SYSDATETIME()
        );

        SET @outResultCode = 50008;
    END CATCH;
END;
GO

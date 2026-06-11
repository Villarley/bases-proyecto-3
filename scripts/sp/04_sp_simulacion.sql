SET NOCOUNT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

USE planilla_obrera;
GO

CREATE OR ALTER PROCEDURE dbo.spSim_InsertarEmpleado
    @inIdUsuario INT
    , @inIP NVARCHAR(45)
    , @inValorDocumentoIdentidad NVARCHAR(50)
    , @inNombre NVARCHAR(300)
    , @inNombrePuesto NVARCHAR(200)
    , @inCuentaBancaria NVARCHAR(50)
    , @inFechaContratacion DATE
    , @inFechaOperacion DATE
    , @outResultCode INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    SET @outResultCode = 50008;

    DECLARE @DayIndex INT;
    DECLARE @DiasHastaViernes INT;
    DECLARE @FechaIngreso DATE;

    BEGIN TRY
        SET @DayIndex = DATEDIFF(DAY, '19000101', @inFechaOperacion) % 7;
        SET @DiasHastaViernes = (4 - @DayIndex + 7) % 7;

        IF (@DiasHastaViernes = 0)
        BEGIN
            SET @DiasHastaViernes = 7;
        END;

        SET @FechaIngreso =
            ISNULL(@inFechaContratacion, DATEADD(DAY, @DiasHastaViernes, @inFechaOperacion));

        EXEC dbo.spEmpleado_Insertar
            @inIdUsuario = @inIdUsuario
            , @inIP = @inIP
            , @inNombre = @inNombre
            , @inValorDocumentoIdentidad = @inValorDocumentoIdentidad
            , @inIdTipoDocumento = NULL
            , @inIdDepartamento = NULL
            , @inNombrePuesto = @inNombrePuesto
            , @inNumeroCuentaBanco = @inCuentaBancaria
            , @inFechaIngreso = @FechaIngreso
            , @inUsername = @inValorDocumentoIdentidad
            , @inPassword = N'1234'
            , @outResultCode = @outResultCode OUTPUT;
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

CREATE OR ALTER PROCEDURE dbo.spSim_AsociarDeduccion
    @inIdUsuario INT
    , @inIP NVARCHAR(45)
    , @inValorDocumentoIdentidad NVARCHAR(50)
    , @inNombreTipoDeduccion NVARCHAR(150)
    , @inMonto DECIMAL(12, 4)
    , @inFechaOperacion DATE
    , @outResultCode INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    SET @outResultCode = 50008;

    DECLARE @IdEmpleado INT;
    DECLARE @IdTipoDeduccion INT;
    DECLARE @EsObligatorio BIT;
    DECLARE @EsPorcentual BIT;
    DECLARE @ValorPorDefecto DECIMAL(12, 4);
    DECLARE @PorcentajeOMonto DECIMAL(12, 4);
    DECLARE @DayIndex INT;
    DECLARE @DiasHastaViernes INT;
    DECLARE @FechaInicioVigencia DATE;
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
            @IdTipoDeduccion = td.Id
            , @EsObligatorio = td.EsObligatorio
            , @EsPorcentual = td.EsPorcentual
            , @ValorPorDefecto = td.ValorPorDefecto
        FROM
            dbo.TipoDeduccion AS td
        WHERE
            (td.Nombre = @inNombreTipoDeduccion);

        IF (@IdTipoDeduccion IS NULL)
        BEGIN
            SET @outResultCode = 50007;

            RETURN;
        END;

        IF (@EsObligatorio = 1)
        BEGIN
            SET @outResultCode = 50015;

            RETURN;
        END;

        IF EXISTS
        (
            SELECT
                1
            FROM
                dbo.EmpleadoDeduccion AS ed
            WHERE
                (ed.IdEmpleado = @IdEmpleado)
                AND (ed.IdTipoDeduccion = @IdTipoDeduccion)
                AND (ed.EsActivo = 1)
        )
        BEGIN
            SET @outResultCode = 50009;

            RETURN;
        END;

        IF (@EsPorcentual = 1)
        BEGIN
            SET @PorcentajeOMonto =
                CASE
                    WHEN (@inMonto > 0) THEN (@inMonto / 100)
                    ELSE @ValorPorDefecto
                END;
        END
        ELSE
        BEGIN
            SET @PorcentajeOMonto = ISNULL(@inMonto, 0);
        END;

        SET @DayIndex = DATEDIFF(DAY, '19000101', @inFechaOperacion) % 7;
        SET @DiasHastaViernes = (4 - @DayIndex + 7) % 7;

        IF (@DiasHastaViernes = 0)
        BEGIN
            SET @DiasHastaViernes = 7;
        END;

        SET @FechaInicioVigencia = DATEADD(DAY, @DiasHastaViernes, @inFechaOperacion);

        IF (@EsPorcentual = 1)
        BEGIN
            SET @Parametros =
                N'{"idEmpleado":'
                + CAST(@IdEmpleado AS NVARCHAR(20))
                + N',"idTipoDeduccion":'
                + CAST(@IdTipoDeduccion AS NVARCHAR(20))
                + N',"valorPorcentual":'
                + CAST(@PorcentajeOMonto AS NVARCHAR(30))
                + N',"valorMontoFijo":null}';
        END
        ELSE
        BEGIN
            SET @Parametros =
                N'{"idEmpleado":'
                + CAST(@IdEmpleado AS NVARCHAR(20))
                + N',"idTipoDeduccion":'
                + CAST(@IdTipoDeduccion AS NVARCHAR(20))
                + N',"valorPorcentual":null,"valorMontoFijo":'
                + CAST(@PorcentajeOMonto AS NVARCHAR(30))
                + N'}';
        END;

        BEGIN TRANSACTION;

        INSERT INTO dbo.EmpleadoDeduccion
        (
            IdEmpleado
            , IdTipoDeduccion
            , PorcentajeOMonto
            , FechaInicioVigencia
            , EsActivo
        )
        VALUES
        (
            @IdEmpleado
            , @IdTipoDeduccion
            , @PorcentajeOMonto
            , @FechaInicioVigencia
            , 1
        );

        EXEC dbo.spBitacora_RegistrarEvento
            @inIdTipoEvento = 7
            , @inIdUsuario = @inIdUsuario
            , @inIP = @inIP
            , @inParametros = @Parametros
            , @inValoresAntes = NULL
            , @inValoresDespues = NULL
            , @outResultCode = @BitacoraResultCode OUTPUT;

        COMMIT TRANSACTION;

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

CREATE OR ALTER PROCEDURE dbo.spSim_DesasociarDeduccion
    @inIdUsuario INT
    , @inIP NVARCHAR(45)
    , @inValorDocumentoIdentidad NVARCHAR(50)
    , @inNombreTipoDeduccion NVARCHAR(150)
    , @inFechaOperacion DATE
    , @outResultCode INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    SET @outResultCode = 50008;

    DECLARE @IdEmpleado INT;
    DECLARE @IdTipoDeduccion INT;
    DECLARE @IdEmpleadoDeduccion INT;
    DECLARE @InicioSemana DATE;
    DECLARE @FechaFinVigencia DATE;
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
            @IdTipoDeduccion = td.Id
        FROM
            dbo.TipoDeduccion AS td
        WHERE
            (td.Nombre = @inNombreTipoDeduccion);

        IF (@IdTipoDeduccion IS NULL)
        BEGIN
            SET @outResultCode = 50007;

            RETURN;
        END;

        SELECT
            @IdEmpleadoDeduccion = ed.Id
        FROM
            dbo.EmpleadoDeduccion AS ed
        WHERE
            (ed.IdEmpleado = @IdEmpleado)
            AND (ed.IdTipoDeduccion = @IdTipoDeduccion)
            AND (ed.EsActivo = 1);

        IF (@IdEmpleadoDeduccion IS NULL)
        BEGIN
            SET @outResultCode = 50010;

            RETURN;
        END;

        SET @InicioSemana =
            DATEADD(
                DAY
                , -((DATEDIFF(DAY, '19000101', @inFechaOperacion) % 7 + 3) % 7)
                , @inFechaOperacion
            );
        SET @FechaFinVigencia = DATEADD(DAY, 6, @InicioSemana);

        SET @Parametros =
            N'{"idEmpleado":'
            + CAST(@IdEmpleado AS NVARCHAR(20))
            + N',"idTipoDeduccion":'
            + CAST(@IdTipoDeduccion AS NVARCHAR(20))
            + N'}';

        BEGIN TRANSACTION;

        UPDATE
            dbo.EmpleadoDeduccion
        SET
            EsActivo = 0
            , FechaFinVigencia = @FechaFinVigencia
        WHERE
            (Id = @IdEmpleadoDeduccion);

        EXEC dbo.spBitacora_RegistrarEvento
            @inIdTipoEvento = 8
            , @inIdUsuario = @inIdUsuario
            , @inIP = @inIP
            , @inParametros = @Parametros
            , @inValoresAntes = NULL
            , @inValoresDespues = NULL
            , @outResultCode = @BitacoraResultCode OUTPUT;

        COMMIT TRANSACTION;

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

CREATE OR ALTER PROCEDURE dbo.spSim_AsignarJornada
    @inIdUsuario INT
    , @inIP NVARCHAR(45)
    , @inValorDocumentoIdentidad NVARCHAR(50)
    , @inNombreJornada NVARCHAR(50)
    , @inInicioSemana DATE
    , @outResultCode INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    SET @outResultCode = 50008;

    DECLARE @IdEmpleado INT;
    DECLARE @IdTipoJornada INT;
    DECLARE @IdSemanaPlanilla INT;
    DECLARE @IdJornadaEmpleadoSemana INT;
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
            @IdTipoJornada = tj.Id
        FROM
            dbo.TipoJornada AS tj
        WHERE
            (tj.Nombre = @inNombreJornada);

        IF (@IdTipoJornada IS NULL)
        BEGIN
            SET @outResultCode = 50011;

            RETURN;
        END;

        SELECT
            @IdSemanaPlanilla = sp.Id
        FROM
            dbo.SemanaPlanilla AS sp
        WHERE
            (sp.FechaInicio = @inInicioSemana);

        SELECT
            @IdJornadaEmpleadoSemana = jes.Id
        FROM
            dbo.JornadaEmpleadoSemana AS jes
        WHERE
            (jes.IdEmpleado = @IdEmpleado)
            AND (jes.FechaInicioSemana = @inInicioSemana);

        SET @Parametros =
            N'{"idEmpleado":'
            + CAST(@IdEmpleado AS NVARCHAR(20))
            + N',"idTipoJornada":'
            + CAST(@IdTipoJornada AS NVARCHAR(20))
            + N'}';

        BEGIN TRANSACTION;

        IF (@IdJornadaEmpleadoSemana IS NOT NULL)
        BEGIN
            UPDATE
                dbo.JornadaEmpleadoSemana
            SET
                IdTipoJornada = @IdTipoJornada
                , IdSemanaPlanilla = @IdSemanaPlanilla
            WHERE
                (Id = @IdJornadaEmpleadoSemana);
        END
        ELSE
        BEGIN
            INSERT INTO dbo.JornadaEmpleadoSemana
            (
                IdEmpleado
                , IdTipoJornada
                , IdSemanaPlanilla
                , FechaInicioSemana
            )
            VALUES
            (
                @IdEmpleado
                , @IdTipoJornada
                , @IdSemanaPlanilla
                , @inInicioSemana
            );
        END;

        EXEC dbo.spBitacora_RegistrarEvento
            @inIdTipoEvento = 15
            , @inIdUsuario = @inIdUsuario
            , @inIP = @inIP
            , @inParametros = @Parametros
            , @inValoresAntes = NULL
            , @inValoresDespues = NULL
            , @outResultCode = @BitacoraResultCode OUTPUT;

        COMMIT TRANSACTION;

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

CREATE OR ALTER PROCEDURE dbo.spSim_AbrirMes
    @inIdUsuario INT
    , @inIP NVARCHAR(45)
    , @inFechaOperacion DATE
    , @outResultCode INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    SET @outResultCode = 50008;

    DECLARE @F DATE;
    DECLARE @EOM DATE;
    DECLARE @DayIndexEOM INT;
    DECLARE @FechaFin DATE;
    DECLARE @Anio INT;
    DECLARE @Mes INT;
    DECLARE @CantidadSemanas INT;
    DECLARE @IdMesPlanilla INT;

    BEGIN TRY
        SET @F = DATEADD(DAY, 1, @inFechaOperacion);

        IF EXISTS
        (
            SELECT
                1
            FROM
                dbo.MesPlanilla AS mp
            WHERE
                (mp.FechaInicio <= @F)
                AND (mp.FechaFin >= @F)
        )
        BEGIN
            SET @outResultCode = 0;

            RETURN;
        END;

        SET @EOM = EOMONTH(@F);
        SET @DayIndexEOM = DATEDIFF(DAY, '19000101', @EOM) % 7;
        SET @FechaFin = DATEADD(DAY, -((@DayIndexEOM - 3 + 7) % 7), @EOM);

        IF (@FechaFin < @F)
        BEGIN
            SET @EOM = EOMONTH(DATEADD(MONTH, 1, @F));
            SET @DayIndexEOM = DATEDIFF(DAY, '19000101', @EOM) % 7;
            SET @FechaFin = DATEADD(DAY, -((@DayIndexEOM - 3 + 7) % 7), @EOM);
        END;

        SET @Anio = YEAR(@FechaFin);
        SET @Mes = MONTH(@FechaFin);
        SET @CantidadSemanas = (DATEDIFF(DAY, @F, @FechaFin) + 1) / 7;

        BEGIN TRANSACTION;

        INSERT INTO dbo.MesPlanilla
        (
            Anio
            , Mes
            , FechaInicio
            , FechaFin
            , CantidadSemanas
        )
        VALUES
        (
            @Anio
            , @Mes
            , @F
            , @FechaFin
            , @CantidadSemanas
        );

        SET @IdMesPlanilla = SCOPE_IDENTITY();

        INSERT INTO dbo.PlanillaMesEmpleado
        (
            IdMesPlanilla
            , IdEmpleado
            , SalarioBrutoMensual
            , TotalDeduccionesMensual
            , SalarioNetoMensual
        )
        SELECT
            @IdMesPlanilla
            , e.Id
            , 0
            , 0
            , 0
        FROM
            dbo.Empleado AS e
        WHERE
            (e.EsActivo = 1);

        COMMIT TRANSACTION;

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

CREATE OR ALTER PROCEDURE dbo.spSim_AbrirSemana
    @inIdUsuario INT
    , @inIP NVARCHAR(45)
    , @inFechaOperacion DATE
    , @outResultCode INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    SET @outResultCode = 50008;

    DECLARE @F DATE;
    DECLARE @IdMesPlanilla INT;
    DECLARE @NumeroSemana INT;
    DECLARE @IdSemanaPlanilla INT;

    BEGIN TRY
        SET @F = DATEADD(DAY, 1, @inFechaOperacion);

        IF EXISTS
        (
            SELECT
                1
            FROM
                dbo.SemanaPlanilla AS sp
            WHERE
                (sp.FechaInicio = @F)
        )
        BEGIN
            SET @outResultCode = 0;

            RETURN;
        END;

        SELECT
            @IdMesPlanilla = mp.Id
        FROM
            dbo.MesPlanilla AS mp
        WHERE
            (mp.FechaInicio <= @F)
            AND (mp.FechaFin >= @F);

        IF (@IdMesPlanilla IS NULL)
        BEGIN
            SET @outResultCode = 50013;

            RETURN;
        END;

        SELECT
            @NumeroSemana = COUNT(1) + 1
        FROM
            dbo.SemanaPlanilla AS sp
        WHERE
            (sp.IdMesPlanilla = @IdMesPlanilla);

        BEGIN TRANSACTION;

        INSERT INTO dbo.SemanaPlanilla
        (
            IdMesPlanilla
            , NumeroSemana
            , FechaInicio
            , FechaFin
        )
        VALUES
        (
            @IdMesPlanilla
            , @NumeroSemana
            , @F
            , DATEADD(DAY, 6, @F)
        );

        SET @IdSemanaPlanilla = SCOPE_IDENTITY();

        INSERT INTO dbo.PlanillaSemanaEmpleado
        (
            IdSemanaPlanilla
            , IdEmpleado
            , SalarioBruto
            , TotalDeducciones
            , SalarioNeto
            , CantidadHorasOrdinarias
            , CantidadHorasExtraNormales
            , CantidadHorasExtraDobles
        )
        SELECT
            @IdSemanaPlanilla
            , e.Id
            , 0
            , 0
            , 0
            , 0
            , 0
            , 0
        FROM
            dbo.Empleado AS e
        WHERE
            (e.EsActivo = 1);

        UPDATE
            dbo.JornadaEmpleadoSemana
        SET
            IdSemanaPlanilla = @IdSemanaPlanilla
        WHERE
            (FechaInicioSemana = @F)
            AND (IdSemanaPlanilla IS NULL);

        COMMIT TRANSACTION;

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

CREATE OR ALTER PROCEDURE dbo.spSim_ProcesarMarca
    @inIdUsuario INT
    , @inIP NVARCHAR(45)
    , @inValorDocumentoIdentidad NVARCHAR(50)
    , @inHoraEntrada DATETIME2(0)
    , @inHoraSalida DATETIME2(0)
    , @outResultCode INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    SET @outResultCode = 50008;

    DECLARE @IdEmpleado INT;
    DECLARE @SalarioXHora DECIMAL(12, 2);
    DECLARE @FechaEntrada DATE;
    DECLARE @FechaSalida DATE;
    DECLARE @InicioSemanaJornada DATE;
    DECLARE @IdTipoJornada INT;
    DECLARE @HoraFin TIME(0);
    DECLARE @CruzaMedianoche BIT;
    DECLARE @FinJornada DATETIME2(0);
    DECLARE @LimiteOrdinario DATETIME2(0);
    DECLARE @HorasOrdinarias INT;
    DECLARE @HorasExtraTotal INT;
    DECLARE @HorasExtraNormales INT;
    DECLARE @HorasExtraDobles INT;
    DECLARE @i INT;
    DECLARE @HoraInicioExtra DATETIME2(0);
    DECLARE @FechaHoraInicioExtra DATE;
    DECLARE @DayIndexExtra INT;
    DECLARE @IdSemanaPlanilla INT;
    DECLARE @IdMesPlanilla INT;
    DECLARE @MontoOrdinarias DECIMAL(14, 2);
    DECLARE @MontoExtraNormales DECIMAL(14, 2);
    DECLARE @MontoExtraDobles DECIMAL(14, 2);
    DECLARE @TotalCredito DECIMAL(14, 2);
    DECLARE @IdPlanillaSemanaEmpleado INT;
    DECLARE @IdPlanillaMesEmpleado INT;
    DECLARE @Parametros NVARCHAR(MAX);
    DECLARE @BitacoraResultCode INT;

    BEGIN TRY
        SELECT
            @IdEmpleado = e.Id
            , @SalarioXHora = p.SalarioXHora
        FROM
            dbo.Empleado AS e
        INNER JOIN
            dbo.Puesto AS p
            ON (p.Id = e.IdPuesto)
        WHERE
            (e.ValorDocumentoIdentidad = @inValorDocumentoIdentidad)
            AND (e.EsActivo = 1);

        IF (@IdEmpleado IS NULL)
        BEGIN
            SET @outResultCode = 50003;

            RETURN;
        END;

        SET @FechaEntrada = CAST(@inHoraEntrada AS DATE);
        SET @FechaSalida = CAST(@inHoraSalida AS DATE);

        SET @InicioSemanaJornada =
            DATEADD(
                DAY
                , -((DATEDIFF(DAY, '19000101', @FechaEntrada) % 7 + 3) % 7)
                , @FechaEntrada
            );

        SELECT
            @IdTipoJornada = jes.IdTipoJornada
            , @HoraFin = tj.HoraFin
            , @CruzaMedianoche = tj.CruzaMedianoche
        FROM
            dbo.JornadaEmpleadoSemana AS jes
        INNER JOIN
            dbo.TipoJornada AS tj
            ON (tj.Id = jes.IdTipoJornada)
        WHERE
            (jes.IdEmpleado = @IdEmpleado)
            AND (jes.FechaInicioSemana = @InicioSemanaJornada);

        IF (@IdTipoJornada IS NULL)
        BEGIN
            SET @outResultCode = 50017;

            RETURN;
        END;

        SET @FinJornada =
            CAST(
                CONCAT(CAST(@FechaEntrada AS NVARCHAR(10)), N' ', CAST(@HoraFin AS NVARCHAR(8)))
                AS DATETIME2(0)
            );

        IF (@CruzaMedianoche = 1)
        BEGIN
            SET @FinJornada = DATEADD(DAY, 1, @FinJornada);
        END;

        SELECT
            @IdSemanaPlanilla = sp.Id
            , @IdMesPlanilla = sp.IdMesPlanilla
        FROM
            dbo.SemanaPlanilla AS sp
        WHERE
            (sp.FechaInicio <= @FechaSalida)
            AND (sp.FechaFin >= @FechaSalida);

        IF (@IdSemanaPlanilla IS NULL)
        BEGIN
            SET @outResultCode = 50018;

            RETURN;
        END;

        SET @LimiteOrdinario =
            CASE
                WHEN (@inHoraSalida < @FinJornada) THEN @inHoraSalida
                ELSE @FinJornada
            END;

        SET @HorasOrdinarias = DATEDIFF(MINUTE, @inHoraEntrada, @LimiteOrdinario) / 60;

        IF (@HorasOrdinarias < 0)
        BEGIN
            SET @HorasOrdinarias = 0;
        END;

        SET @HorasExtraTotal = 0;
        SET @HorasExtraNormales = 0;
        SET @HorasExtraDobles = 0;

        IF (@inHoraSalida > @FinJornada)
        BEGIN
            SET @HorasExtraTotal = DATEDIFF(MINUTE, @FinJornada, @inHoraSalida) / 60;

            IF (@HorasExtraTotal < 0)
            BEGIN
                SET @HorasExtraTotal = 0;
            END;

            SET @i = 0;

            WHILE (@i < @HorasExtraTotal)
            BEGIN
                SET @HoraInicioExtra = DATEADD(HOUR, @i, @FinJornada);
                SET @FechaHoraInicioExtra = CAST(@HoraInicioExtra AS DATE);
                SET @DayIndexExtra = DATEDIFF(DAY, '19000101', @FechaHoraInicioExtra) % 7;

                IF (
                    (@DayIndexExtra = 6)
                    OR EXISTS
                    (
                        SELECT
                            1
                        FROM
                            dbo.Feriado AS f
                        WHERE
                            (f.Fecha = @FechaHoraInicioExtra)
                    )
                )
                BEGIN
                    SET @HorasExtraDobles = @HorasExtraDobles + 1;
                END
                ELSE
                BEGIN
                    SET @HorasExtraNormales = @HorasExtraNormales + 1;
                END;

                SET @i = @i + 1;
            END;
        END;

        SET @MontoOrdinarias = @HorasOrdinarias * @SalarioXHora;
        SET @MontoExtraNormales = @HorasExtraNormales * @SalarioXHora * 1.5;
        SET @MontoExtraDobles = @HorasExtraDobles * @SalarioXHora * 2.0;
        SET @TotalCredito = @MontoOrdinarias + @MontoExtraNormales + @MontoExtraDobles;

        SET @Parametros =
            N'{"idEmpleado":'
            + CAST(@IdEmpleado AS NVARCHAR(20))
            + N',"marcaInicio":"'
            + CONVERT(NVARCHAR(19), @inHoraEntrada, 120)
            + N'","marcaFin":"'
            + CONVERT(NVARCHAR(19), @inHoraSalida, 120)
            + N'"}';

        BEGIN TRANSACTION;

        INSERT INTO dbo.MarcaAsistencia
        (
            IdEmpleado
            , Fecha
            , HoraEntrada
            , HoraSalida
            , Procesada
        )
        VALUES
        (
            @IdEmpleado
            , @FechaEntrada
            , @inHoraEntrada
            , @inHoraSalida
            , 1
        );

        IF NOT EXISTS
        (
            SELECT
                1
            FROM
                dbo.PlanillaSemanaEmpleado AS pse
            WHERE
                (pse.IdSemanaPlanilla = @IdSemanaPlanilla)
                AND (pse.IdEmpleado = @IdEmpleado)
        )
        BEGIN
            INSERT INTO dbo.PlanillaSemanaEmpleado
            (
                IdSemanaPlanilla
                , IdEmpleado
                , SalarioBruto
                , TotalDeducciones
                , SalarioNeto
                , CantidadHorasOrdinarias
                , CantidadHorasExtraNormales
                , CantidadHorasExtraDobles
            )
            VALUES
            (
                @IdSemanaPlanilla
                , @IdEmpleado
                , 0
                , 0
                , 0
                , 0
                , 0
                , 0
            );
        END;

        SELECT
            @IdPlanillaSemanaEmpleado = pse.Id
        FROM
            dbo.PlanillaSemanaEmpleado AS pse
        WHERE
            (pse.IdSemanaPlanilla = @IdSemanaPlanilla)
            AND (pse.IdEmpleado = @IdEmpleado);

        IF NOT EXISTS
        (
            SELECT
                1
            FROM
                dbo.PlanillaMesEmpleado AS pme
            WHERE
                (pme.IdMesPlanilla = @IdMesPlanilla)
                AND (pme.IdEmpleado = @IdEmpleado)
        )
        BEGIN
            INSERT INTO dbo.PlanillaMesEmpleado
            (
                IdMesPlanilla
                , IdEmpleado
                , SalarioBrutoMensual
                , TotalDeduccionesMensual
                , SalarioNetoMensual
            )
            VALUES
            (
                @IdMesPlanilla
                , @IdEmpleado
                , 0
                , 0
                , 0
            );
        END;

        SELECT
            @IdPlanillaMesEmpleado = pme.Id
        FROM
            dbo.PlanillaMesEmpleado AS pme
        WHERE
            (pme.IdMesPlanilla = @IdMesPlanilla)
            AND (pme.IdEmpleado = @IdEmpleado);

        IF (@HorasOrdinarias > 0)
        BEGIN
            INSERT INTO dbo.Movimiento
            (
                IdEmpleado
                , IdPlanillaSemanaEmpleado
                , IdTipoMovimiento
                , IdTipoDeduccion
                , Fecha
                , CantidadHoras
                , Monto
                , IdPostByUser
                , PostInIP
            )
            VALUES
            (
                @IdEmpleado
                , @IdPlanillaSemanaEmpleado
                , 1
                , NULL
                , @FechaEntrada
                , @HorasOrdinarias
                , @MontoOrdinarias
                , @inIdUsuario
                , @inIP
            );
        END;

        IF (@HorasExtraNormales > 0)
        BEGIN
            INSERT INTO dbo.Movimiento
            (
                IdEmpleado
                , IdPlanillaSemanaEmpleado
                , IdTipoMovimiento
                , IdTipoDeduccion
                , Fecha
                , CantidadHoras
                , Monto
                , IdPostByUser
                , PostInIP
            )
            VALUES
            (
                @IdEmpleado
                , @IdPlanillaSemanaEmpleado
                , 2
                , NULL
                , @FechaEntrada
                , @HorasExtraNormales
                , @MontoExtraNormales
                , @inIdUsuario
                , @inIP
            );
        END;

        IF (@HorasExtraDobles > 0)
        BEGIN
            INSERT INTO dbo.Movimiento
            (
                IdEmpleado
                , IdPlanillaSemanaEmpleado
                , IdTipoMovimiento
                , IdTipoDeduccion
                , Fecha
                , CantidadHoras
                , Monto
                , IdPostByUser
                , PostInIP
            )
            VALUES
            (
                @IdEmpleado
                , @IdPlanillaSemanaEmpleado
                , 3
                , NULL
                , @FechaEntrada
                , @HorasExtraDobles
                , @MontoExtraDobles
                , @inIdUsuario
                , @inIP
            );
        END;

        UPDATE
            dbo.PlanillaSemanaEmpleado
        SET
            SalarioBruto = SalarioBruto + @TotalCredito
            , SalarioNeto = SalarioNeto + @TotalCredito
            , CantidadHorasOrdinarias = CantidadHorasOrdinarias + @HorasOrdinarias
            , CantidadHorasExtraNormales = CantidadHorasExtraNormales + @HorasExtraNormales
            , CantidadHorasExtraDobles = CantidadHorasExtraDobles + @HorasExtraDobles
        WHERE
            (Id = @IdPlanillaSemanaEmpleado);

        UPDATE
            dbo.PlanillaMesEmpleado
        SET
            SalarioBrutoMensual = SalarioBrutoMensual + @TotalCredito
            , SalarioNetoMensual = SalarioNetoMensual + @TotalCredito
        WHERE
            (Id = @IdPlanillaMesEmpleado);

        EXEC dbo.spBitacora_RegistrarEvento
            @inIdTipoEvento = 14
            , @inIdUsuario = @inIdUsuario
            , @inIP = @inIP
            , @inParametros = @Parametros
            , @inValoresAntes = NULL
            , @inValoresDespues = NULL
            , @outResultCode = @BitacoraResultCode OUTPUT;

        COMMIT TRANSACTION;

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

CREATE OR ALTER PROCEDURE dbo.spSim_CerrarSemana
    @inIdUsuario INT
    , @inIP NVARCHAR(45)
    , @inFechaOperacion DATE
    , @outResultCode INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    SET @outResultCode = 50008;

    DECLARE @IdSemanaPlanilla INT;
    DECLARE @FechaFinSemana DATE;
    DECLARE @IdMesPlanilla INT;
    DECLARE @CantidadSemanas INT;
    DECLARE @FechaFinMes DATE;
    DECLARE @Empleados TABLE
    (
        RowNum INT NOT NULL PRIMARY KEY
        , IdEmpleado INT NOT NULL
        , IdPlanillaSemanaEmpleado INT NOT NULL
        , SalarioBruto DECIMAL(14, 2) NOT NULL
    );
    DECLARE @RowNum INT;
    DECLARE @MaxRowNum INT;
    DECLARE @IdEmpleado INT;
    DECLARE @IdPlanillaSemanaEmpleado INT;
    DECLARE @SalarioBruto DECIMAL(14, 2);
    DECLARE @Deducciones TABLE
    (
        RowNum INT NOT NULL PRIMARY KEY
        , IdTipoDeduccion INT NOT NULL
        , IdTipoMovimiento INT NOT NULL
        , EsPorcentual BIT NOT NULL
        , Porcentaje DECIMAL(12, 4) NULL
        , Monto DECIMAL(14, 2) NOT NULL
    );
    DECLARE @TotalDeduccionesEmpleado DECIMAL(14, 2);
    DECLARE @IdPlanillaMesEmpleado INT;
    DECLARE @IdTipoDeduccion INT;
    DECLARE @IdTipoMovimiento INT;
    DECLARE @Porcentaje DECIMAL(12, 4);
    DECLARE @MontoDeduccion DECIMAL(14, 2);
    DECLARE @DedRowNum INT;
    DECLARE @DedMaxRowNum INT;

    BEGIN TRY
        SELECT
            @IdSemanaPlanilla = sp.Id
            , @FechaFinSemana = sp.FechaFin
            , @IdMesPlanilla = sp.IdMesPlanilla
        FROM
            dbo.SemanaPlanilla AS sp
        WHERE
            (sp.FechaInicio <= @inFechaOperacion)
            AND (sp.FechaFin >= @inFechaOperacion);

        IF (@IdSemanaPlanilla IS NULL)
        BEGIN
            SET @outResultCode = 0;

            RETURN;
        END;

        SELECT
            @CantidadSemanas = mp.CantidadSemanas
            , @FechaFinMes = mp.FechaFin
        FROM
            dbo.MesPlanilla AS mp
        WHERE
            (mp.Id = @IdMesPlanilla);

        INSERT INTO @Empleados
        (
            RowNum
            , IdEmpleado
            , IdPlanillaSemanaEmpleado
            , SalarioBruto
        )
        SELECT
            ROW_NUMBER() OVER (ORDER BY pse.IdEmpleado ASC)
            , pse.IdEmpleado
            , pse.Id
            , pse.SalarioBruto
        FROM
            dbo.PlanillaSemanaEmpleado AS pse
        WHERE
            (pse.IdSemanaPlanilla = @IdSemanaPlanilla);

        SELECT
            @MaxRowNum = MAX(e.RowNum)
        FROM
            @Empleados AS e;

        SET @RowNum = 1;

        WHILE (@RowNum <= @MaxRowNum)
        BEGIN
            SELECT
                @IdEmpleado = e.IdEmpleado
                , @IdPlanillaSemanaEmpleado = e.IdPlanillaSemanaEmpleado
                , @SalarioBruto = e.SalarioBruto
            FROM
                @Empleados AS e
            WHERE
                (e.RowNum = @RowNum);

            DELETE FROM @Deducciones;

            INSERT INTO @Deducciones
            (
                RowNum
                , IdTipoDeduccion
                , IdTipoMovimiento
                , EsPorcentual
                , Porcentaje
                , Monto
            )
            SELECT
                ROW_NUMBER() OVER (ORDER BY td.Id ASC)
                , td.Id
                , td.IdTipoMovimiento
                , td.EsPorcentual
                , CASE
                    WHEN (td.EsPorcentual = 1) THEN ed.PorcentajeOMonto
                    ELSE NULL
                END
                , CASE
                    WHEN (td.EsPorcentual = 1) THEN
                        ROUND(ed.PorcentajeOMonto * @SalarioBruto, 2)
                    ELSE
                        ROUND(ed.PorcentajeOMonto / @CantidadSemanas, 2)
                END
            FROM
                dbo.EmpleadoDeduccion AS ed
            INNER JOIN
                dbo.TipoDeduccion AS td
                ON (td.Id = ed.IdTipoDeduccion)
            WHERE
                (ed.IdEmpleado = @IdEmpleado)
                AND (ed.EsActivo = 1)
                AND (ed.FechaInicioVigencia <= @FechaFinSemana)
                AND (
                    (ed.FechaFinVigencia IS NULL)
                    OR (ed.FechaFinVigencia >= @FechaFinSemana)
                );

            SELECT
                @TotalDeduccionesEmpleado = ISNULL(SUM(d.Monto), 0)
            FROM
                @Deducciones AS d;

            BEGIN TRANSACTION;

            SET @DedRowNum = 1;

            SELECT
                @DedMaxRowNum = MAX(d.RowNum)
            FROM
                @Deducciones AS d;

            WHILE (@DedRowNum <= ISNULL(@DedMaxRowNum, 0))
            BEGIN
                SELECT
                    @IdTipoDeduccion = d.IdTipoDeduccion
                    , @IdTipoMovimiento = d.IdTipoMovimiento
                    , @Porcentaje = d.Porcentaje
                    , @MontoDeduccion = d.Monto
                FROM
                    @Deducciones AS d
                WHERE
                    (d.RowNum = @DedRowNum);

                INSERT INTO dbo.Movimiento
                (
                    IdEmpleado
                    , IdPlanillaSemanaEmpleado
                    , IdTipoMovimiento
                    , IdTipoDeduccion
                    , Fecha
                    , CantidadHoras
                    , Monto
                    , IdPostByUser
                    , PostInIP
                )
                VALUES
                (
                    @IdEmpleado
                    , @IdPlanillaSemanaEmpleado
                    , @IdTipoMovimiento
                    , @IdTipoDeduccion
                    , @inFechaOperacion
                    , NULL
                    , @MontoDeduccion
                    , @inIdUsuario
                    , @inIP
                );

                SET @DedRowNum = @DedRowNum + 1;
            END;

            UPDATE
                dbo.PlanillaSemanaEmpleado
            SET
                TotalDeducciones = TotalDeducciones + @TotalDeduccionesEmpleado
                , SalarioNeto = SalarioBruto - (TotalDeducciones + @TotalDeduccionesEmpleado)
            WHERE
                (Id = @IdPlanillaSemanaEmpleado);

            IF NOT EXISTS
            (
                SELECT
                    1
                FROM
                    dbo.PlanillaMesEmpleado AS pme
                WHERE
                    (pme.IdMesPlanilla = @IdMesPlanilla)
                    AND (pme.IdEmpleado = @IdEmpleado)
            )
            BEGIN
                INSERT INTO dbo.PlanillaMesEmpleado
                (
                    IdMesPlanilla
                    , IdEmpleado
                    , SalarioBrutoMensual
                    , TotalDeduccionesMensual
                    , SalarioNetoMensual
                )
                VALUES
                (
                    @IdMesPlanilla
                    , @IdEmpleado
                    , 0
                    , 0
                    , 0
                );
            END;

            SELECT
                @IdPlanillaMesEmpleado = pme.Id
            FROM
                dbo.PlanillaMesEmpleado AS pme
            WHERE
                (pme.IdMesPlanilla = @IdMesPlanilla)
                AND (pme.IdEmpleado = @IdEmpleado);

            UPDATE
                dbo.PlanillaMesEmpleado
            SET
                TotalDeduccionesMensual = TotalDeduccionesMensual + @TotalDeduccionesEmpleado
                , SalarioNetoMensual =
                    SalarioBrutoMensual - (TotalDeduccionesMensual + @TotalDeduccionesEmpleado)
            WHERE
                (Id = @IdPlanillaMesEmpleado);

            SET @DedRowNum = 1;

            WHILE (@DedRowNum <= ISNULL(@DedMaxRowNum, 0))
            BEGIN
                SELECT
                    @IdTipoDeduccion = d.IdTipoDeduccion
                    , @Porcentaje = d.Porcentaje
                    , @MontoDeduccion = d.Monto
                FROM
                    @Deducciones AS d
                WHERE
                    (d.RowNum = @DedRowNum);

                IF EXISTS
                (
                    SELECT
                        1
                    FROM
                        dbo.DeduccionEmpleadoMes AS dem
                    WHERE
                        (dem.IdPlanillaMesEmpleado = @IdPlanillaMesEmpleado)
                        AND (dem.IdTipoDeduccion = @IdTipoDeduccion)
                )
                BEGIN
                    UPDATE
                        dbo.DeduccionEmpleadoMes
                    SET
                        MontoAcumulado = MontoAcumulado + @MontoDeduccion
                    WHERE
                        (IdPlanillaMesEmpleado = @IdPlanillaMesEmpleado)
                        AND (IdTipoDeduccion = @IdTipoDeduccion);
                END
                ELSE
                BEGIN
                    INSERT INTO dbo.DeduccionEmpleadoMes
                    (
                        IdPlanillaMesEmpleado
                        , IdTipoDeduccion
                        , MontoAcumulado
                        , PorcentajeAplicado
                    )
                    VALUES
                    (
                        @IdPlanillaMesEmpleado
                        , @IdTipoDeduccion
                        , @MontoDeduccion
                        , @Porcentaje
                    );
                END;

                SET @DedRowNum = @DedRowNum + 1;
            END;

            COMMIT TRANSACTION;

            SET @RowNum = @RowNum + 1;
        END;

        BEGIN TRANSACTION;

        UPDATE
            dbo.SemanaPlanilla
        SET
            EstaCerrada = 1
        WHERE
            (Id = @IdSemanaPlanilla);

        IF (@FechaFinSemana = @FechaFinMes)
        BEGIN
            UPDATE
                dbo.MesPlanilla
            SET
                EstaCerrado = 1
            WHERE
                (Id = @IdMesPlanilla);
        END;

        COMMIT TRANSACTION;

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

CREATE OR ALTER PROCEDURE dbo.spSim_ProcesarFechaOperacion
    @inIdUsuario INT
    , @inIP NVARCHAR(45)
    , @inXml XML
    , @inFecha DATE
    , @outResultCode INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    SET @outResultCode = 50008;

    DECLARE @InsertarEmpleado TABLE
    (
        RowNum INT NOT NULL PRIMARY KEY
        , ValorDocumentoIdentidad NVARCHAR(50) NOT NULL
        , Nombre NVARCHAR(300) NOT NULL
        , Puesto NVARCHAR(200) NOT NULL
        , CuentaBancaria NVARCHAR(50) NOT NULL
        , FechaContratacion DATE NULL
    );
    DECLARE @EliminarEmpleado TABLE
    (
        RowNum INT NOT NULL PRIMARY KEY
        , ValorDocumentoIdentidad NVARCHAR(50) NOT NULL
    );
    DECLARE @AsociarDeduccion TABLE
    (
        RowNum INT NOT NULL PRIMARY KEY
        , ValorDocumentoIdentidad NVARCHAR(50) NOT NULL
        , TipoDeduccion NVARCHAR(150) NOT NULL
        , MontoFijo DECIMAL(12, 4) NULL
    );
    DECLARE @DesasociarDeduccion TABLE
    (
        RowNum INT NOT NULL PRIMARY KEY
        , ValorDocumentoIdentidad NVARCHAR(50) NOT NULL
        , TipoDeduccion NVARCHAR(150) NOT NULL
    );
    DECLARE @MarcaAsistencia TABLE
    (
        RowNum INT NOT NULL PRIMARY KEY
        , ValorDocumentoIdentidad NVARCHAR(50) NOT NULL
        , HoraEntradaStr NVARCHAR(20) NOT NULL
        , HoraSalidaStr NVARCHAR(20) NOT NULL
        , HoraEntrada DATETIME2(0) NULL
        , HoraSalida DATETIME2(0) NULL
        , FechaSalida DATE NULL
    );
    DECLARE @MarcasPasoE TABLE
    (
        RowNum INT NOT NULL PRIMARY KEY
        , ValorDocumentoIdentidad NVARCHAR(50) NOT NULL
        , HoraEntrada DATETIME2(0) NOT NULL
        , HoraSalida DATETIME2(0) NOT NULL
    );
    DECLARE @MarcasPasoG TABLE
    (
        RowNum INT NOT NULL PRIMARY KEY
        , ValorDocumentoIdentidad NVARCHAR(50) NOT NULL
        , HoraEntrada DATETIME2(0) NOT NULL
        , HoraSalida DATETIME2(0) NOT NULL
    );
    DECLARE @AsignarJornada TABLE
    (
        RowNum INT NOT NULL PRIMARY KEY
        , ValorDocumentoIdentidad NVARCHAR(50) NOT NULL
        , Jornada NVARCHAR(50) NOT NULL
        , InicioSemana DATE NOT NULL
    );
    DECLARE @InicioSemanaActual DATE;
    DECLARE @FinSemanaActual DATE;
    DECLARE @DayIndex INT;
    DECLARE @RowNum INT;
    DECLARE @MaxRowNum INT;
    DECLARE @ValorDocumentoIdentidad NVARCHAR(50);
    DECLARE @Nombre NVARCHAR(300);
    DECLARE @Puesto NVARCHAR(200);
    DECLARE @CuentaBancaria NVARCHAR(50);
    DECLARE @FechaContratacion DATE;
    DECLARE @TipoDeduccion NVARCHAR(150);
    DECLARE @MontoFijo DECIMAL(12, 4);
    DECLARE @Jornada NVARCHAR(50);
    DECLARE @InicioSemana DATE;
    DECLARE @HoraEntradaStr NVARCHAR(20);
    DECLARE @HoraSalidaStr NVARCHAR(20);
    DECLARE @HoraEntrada DATETIME2(0);
    DECLARE @HoraSalida DATETIME2(0);
    DECLARE @ChildResultCode INT;

    BEGIN TRY
        INSERT INTO @InsertarEmpleado
        (
            RowNum
            , ValorDocumentoIdentidad
            , Nombre
            , Puesto
            , CuentaBancaria
            , FechaContratacion
        )
        SELECT
            ROW_NUMBER() OVER (ORDER BY (SELECT NULL))
            , T.c.value(N'@ValorDocumentoIdentidad', N'NVARCHAR(50)')
            , T.c.value(N'@Nombre', N'NVARCHAR(300)')
            , T.c.value(N'@Puesto', N'NVARCHAR(200)')
            , T.c.value(N'@CuentaBancaria', N'NVARCHAR(50)')
            , T.c.value(N'@FechaContratacion', N'DATE')
        FROM
            @inXml.nodes(N'/Operaciones/FechaOperacion') AS FO (n)
        CROSS APPLY
            n.nodes(N'InsertarEmpleado') AS T (c)
        WHERE
            (FO.n.value(N'@Fecha', N'DATE') = @inFecha);

        INSERT INTO @EliminarEmpleado
        (
            RowNum
            , ValorDocumentoIdentidad
        )
        SELECT
            ROW_NUMBER() OVER (ORDER BY (SELECT NULL))
            , T.c.value(N'@ValorDocumentoIdentidad', N'NVARCHAR(50)')
        FROM
            @inXml.nodes(N'/Operaciones/FechaOperacion') AS FO (n)
        CROSS APPLY
            n.nodes(N'EliminarEmpleado') AS T (c)
        WHERE
            (FO.n.value(N'@Fecha', N'DATE') = @inFecha);

        INSERT INTO @AsociarDeduccion
        (
            RowNum
            , ValorDocumentoIdentidad
            , TipoDeduccion
            , MontoFijo
        )
        SELECT
            ROW_NUMBER() OVER (ORDER BY (SELECT NULL))
            , T.c.value(N'@ValorDocumentoIdentidad', N'NVARCHAR(50)')
            , T.c.value(N'@TipoDeduccion', N'NVARCHAR(150)')
            , T.c.value(N'@MontoFijo', N'DECIMAL(12, 4)')
        FROM
            @inXml.nodes(N'/Operaciones/FechaOperacion') AS FO (n)
        CROSS APPLY
            n.nodes(N'AsociaEmpleadoConDeduccion') AS T (c)
        WHERE
            (FO.n.value(N'@Fecha', N'DATE') = @inFecha);

        INSERT INTO @DesasociarDeduccion
        (
            RowNum
            , ValorDocumentoIdentidad
            , TipoDeduccion
        )
        SELECT
            ROW_NUMBER() OVER (ORDER BY (SELECT NULL))
            , T.c.value(N'@ValorDocumentoIdentidad', N'NVARCHAR(50)')
            , T.c.value(N'@TipoDeduccion', N'NVARCHAR(150)')
        FROM
            @inXml.nodes(N'/Operaciones/FechaOperacion') AS FO (n)
        CROSS APPLY
            n.nodes(N'DesasociaEmpleadoConDeduccion') AS T (c)
        WHERE
            (FO.n.value(N'@Fecha', N'DATE') = @inFecha);

        INSERT INTO @MarcaAsistencia
        (
            RowNum
            , ValorDocumentoIdentidad
            , HoraEntradaStr
            , HoraSalidaStr
        )
        SELECT
            ROW_NUMBER() OVER (ORDER BY (SELECT NULL))
            , T.c.value(N'@ValorDocumentoIdentidad', N'NVARCHAR(50)')
            , T.c.value(N'@HoraEntrada', N'NVARCHAR(20)')
            , T.c.value(N'@HoraSalida', N'NVARCHAR(20)')
        FROM
            @inXml.nodes(N'/Operaciones/FechaOperacion') AS FO (n)
        CROSS APPLY
            n.nodes(N'MarcaAsistencia') AS T (c)
        WHERE
            (FO.n.value(N'@Fecha', N'DATE') = @inFecha);

        INSERT INTO @AsignarJornada
        (
            RowNum
            , ValorDocumentoIdentidad
            , Jornada
            , InicioSemana
        )
        SELECT
            ROW_NUMBER() OVER (ORDER BY (SELECT NULL))
            , T.c.value(N'@ValorDocumentoIdentidad', N'NVARCHAR(50)')
            , T.c.value(N'@Jornada', N'NVARCHAR(50)')
            , T.c.value(N'@InicioSemana', N'DATE')
        FROM
            @inXml.nodes(N'/Operaciones/FechaOperacion') AS FO (n)
        CROSS APPLY
            n.nodes(N'AsignarJornada') AS T (c)
        WHERE
            (FO.n.value(N'@Fecha', N'DATE') = @inFecha);

        SET @InicioSemanaActual =
            DATEADD(
                DAY
                , -((DATEDIFF(DAY, '19000101', @inFecha) % 7 + 3) % 7)
                , @inFecha
            );
        SET @FinSemanaActual = DATEADD(DAY, 6, @InicioSemanaActual);

        UPDATE
            ma
        SET
            HoraEntrada = TRY_CONVERT(DATETIME2(0), ma.HoraEntradaStr)
            , HoraSalida = TRY_CONVERT(DATETIME2(0), ma.HoraSalidaStr)
            , FechaSalida = CAST(TRY_CONVERT(DATETIME2(0), ma.HoraSalidaStr) AS DATE)
        FROM
            @MarcaAsistencia AS ma;

        IF EXISTS
        (
            SELECT
                1
            FROM
                @MarcaAsistencia AS ma
            WHERE
                (ma.HoraEntrada IS NULL)
                OR (ma.HoraSalida IS NULL)
        )
        BEGIN
            SET @outResultCode = 50015;

            RETURN;
        END;

        INSERT INTO @MarcasPasoE
        (
            RowNum
            , ValorDocumentoIdentidad
            , HoraEntrada
            , HoraSalida
        )
        SELECT
            ROW_NUMBER() OVER (ORDER BY ma.RowNum ASC)
            , ma.ValorDocumentoIdentidad
            , ma.HoraEntrada
            , ma.HoraSalida
        FROM
            @MarcaAsistencia AS ma
        WHERE
            (ma.FechaSalida <= @FinSemanaActual);

        INSERT INTO @MarcasPasoG
        (
            RowNum
            , ValorDocumentoIdentidad
            , HoraEntrada
            , HoraSalida
        )
        SELECT
            ROW_NUMBER() OVER (ORDER BY ma.RowNum ASC)
            , ma.ValorDocumentoIdentidad
            , ma.HoraEntrada
            , ma.HoraSalida
        FROM
            @MarcaAsistencia AS ma
        WHERE
            (ma.FechaSalida > @FinSemanaActual);

        SET @RowNum = 1;

        SELECT
            @MaxRowNum = MAX(ie.RowNum)
        FROM
            @InsertarEmpleado AS ie;

        WHILE (@RowNum <= ISNULL(@MaxRowNum, 0))
        BEGIN
            SELECT
                @ValorDocumentoIdentidad = ie.ValorDocumentoIdentidad
                , @Nombre = ie.Nombre
                , @Puesto = ie.Puesto
                , @CuentaBancaria = ie.CuentaBancaria
                , @FechaContratacion = ie.FechaContratacion
            FROM
                @InsertarEmpleado AS ie
            WHERE
                (ie.RowNum = @RowNum);

            EXEC dbo.spSim_InsertarEmpleado
                @inIdUsuario = @inIdUsuario
                , @inIP = @inIP
                , @inValorDocumentoIdentidad = @ValorDocumentoIdentidad
                , @inNombre = @Nombre
                , @inNombrePuesto = @Puesto
                , @inCuentaBancaria = @CuentaBancaria
                , @inFechaContratacion = @FechaContratacion
                , @inFechaOperacion = @inFecha
                , @outResultCode = @ChildResultCode OUTPUT;

            SET @RowNum = @RowNum + 1;
        END;

        SET @RowNum = 1;

        SELECT
            @MaxRowNum = MAX(de.RowNum)
        FROM
            @EliminarEmpleado AS de;

        WHILE (@RowNum <= ISNULL(@MaxRowNum, 0))
        BEGIN
            SELECT
                @ValorDocumentoIdentidad = de.ValorDocumentoIdentidad
            FROM
                @EliminarEmpleado AS de
            WHERE
                (de.RowNum = @RowNum);

            EXEC dbo.spEmpleado_Eliminar
                @inIdUsuario = @inIdUsuario
                , @inIP = @inIP
                , @inValorDocumentoIdentidad = @ValorDocumentoIdentidad
                , @inFechaSalida = @inFecha
                , @outResultCode = @ChildResultCode OUTPUT;

            SET @RowNum = @RowNum + 1;
        END;

        SET @RowNum = 1;

        SELECT
            @MaxRowNum = MAX(ad.RowNum)
        FROM
            @AsociarDeduccion AS ad;

        WHILE (@RowNum <= ISNULL(@MaxRowNum, 0))
        BEGIN
            SELECT
                @ValorDocumentoIdentidad = ad.ValorDocumentoIdentidad
                , @TipoDeduccion = ad.TipoDeduccion
                , @MontoFijo = ad.MontoFijo
            FROM
                @AsociarDeduccion AS ad
            WHERE
                (ad.RowNum = @RowNum);

            EXEC dbo.spSim_AsociarDeduccion
                @inIdUsuario = @inIdUsuario
                , @inIP = @inIP
                , @inValorDocumentoIdentidad = @ValorDocumentoIdentidad
                , @inNombreTipoDeduccion = @TipoDeduccion
                , @inMonto = @MontoFijo
                , @inFechaOperacion = @inFecha
                , @outResultCode = @ChildResultCode OUTPUT;

            SET @RowNum = @RowNum + 1;
        END;

        SET @RowNum = 1;

        SELECT
            @MaxRowNum = MAX(dd.RowNum)
        FROM
            @DesasociarDeduccion AS dd;

        WHILE (@RowNum <= ISNULL(@MaxRowNum, 0))
        BEGIN
            SELECT
                @ValorDocumentoIdentidad = dd.ValorDocumentoIdentidad
                , @TipoDeduccion = dd.TipoDeduccion
            FROM
                @DesasociarDeduccion AS dd
            WHERE
                (dd.RowNum = @RowNum);

            EXEC dbo.spSim_DesasociarDeduccion
                @inIdUsuario = @inIdUsuario
                , @inIP = @inIP
                , @inValorDocumentoIdentidad = @ValorDocumentoIdentidad
                , @inNombreTipoDeduccion = @TipoDeduccion
                , @inFechaOperacion = @inFecha
                , @outResultCode = @ChildResultCode OUTPUT;

            SET @RowNum = @RowNum + 1;
        END;

        SET @RowNum = 1;

        SELECT
            @MaxRowNum = MAX(ma.RowNum)
        FROM
            @MarcasPasoE AS ma;

        WHILE (@RowNum <= ISNULL(@MaxRowNum, 0))
        BEGIN
            SELECT
                @ValorDocumentoIdentidad = ma.ValorDocumentoIdentidad
                , @HoraEntrada = ma.HoraEntrada
                , @HoraSalida = ma.HoraSalida
            FROM
                @MarcasPasoE AS ma
            WHERE
                (ma.RowNum = @RowNum);

            EXEC dbo.spSim_ProcesarMarca
                @inIdUsuario = @inIdUsuario
                , @inIP = @inIP
                , @inValorDocumentoIdentidad = @ValorDocumentoIdentidad
                , @inHoraEntrada = @HoraEntrada
                , @inHoraSalida = @HoraSalida
                , @outResultCode = @ChildResultCode OUTPUT;

            SET @RowNum = @RowNum + 1;
        END;

        SET @DayIndex = DATEDIFF(DAY, '19000101', @inFecha) % 7;

        IF (@DayIndex = 3)
        BEGIN
            EXEC dbo.spSim_CerrarSemana
                @inIdUsuario = @inIdUsuario
                , @inIP = @inIP
                , @inFechaOperacion = @inFecha
                , @outResultCode = @ChildResultCode OUTPUT;

            EXEC dbo.spSim_AbrirMes
                @inIdUsuario = @inIdUsuario
                , @inIP = @inIP
                , @inFechaOperacion = @inFecha
                , @outResultCode = @ChildResultCode OUTPUT;

            EXEC dbo.spSim_AbrirSemana
                @inIdUsuario = @inIdUsuario
                , @inIP = @inIP
                , @inFechaOperacion = @inFecha
                , @outResultCode = @ChildResultCode OUTPUT;

        END;

        SET @RowNum = 1;

        SELECT
            @MaxRowNum = MAX(ma.RowNum)
        FROM
            @MarcasPasoG AS ma;

        WHILE (@RowNum <= ISNULL(@MaxRowNum, 0))
        BEGIN
            SELECT
                @ValorDocumentoIdentidad = ma.ValorDocumentoIdentidad
                , @HoraEntrada = ma.HoraEntrada
                , @HoraSalida = ma.HoraSalida
            FROM
                @MarcasPasoG AS ma
            WHERE
                (ma.RowNum = @RowNum);

            EXEC dbo.spSim_ProcesarMarca
                @inIdUsuario = @inIdUsuario
                , @inIP = @inIP
                , @inValorDocumentoIdentidad = @ValorDocumentoIdentidad
                , @inHoraEntrada = @HoraEntrada
                , @inHoraSalida = @HoraSalida
                , @outResultCode = @ChildResultCode OUTPUT;

            SET @RowNum = @RowNum + 1;
        END;

        SET @RowNum = 1;

        SELECT
            @MaxRowNum = MAX(aj.RowNum)
        FROM
            @AsignarJornada AS aj;

        WHILE (@RowNum <= ISNULL(@MaxRowNum, 0))
        BEGIN
            SELECT
                @ValorDocumentoIdentidad = aj.ValorDocumentoIdentidad
                , @Jornada = aj.Jornada
                , @InicioSemana = aj.InicioSemana
            FROM
                @AsignarJornada AS aj
            WHERE
                (aj.RowNum = @RowNum);

            EXEC dbo.spSim_AsignarJornada
                @inIdUsuario = @inIdUsuario
                , @inIP = @inIP
                , @inValorDocumentoIdentidad = @ValorDocumentoIdentidad
                , @inNombreJornada = @Jornada
                , @inInicioSemana = @InicioSemana
                , @outResultCode = @ChildResultCode OUTPUT;

            SET @RowNum = @RowNum + 1;
        END;

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

CREATE OR ALTER PROCEDURE dbo.spSimulacion_Ejecutar
    @inXml XML
    , @inIP NVARCHAR(45)
    , @outResultCode INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    SET @outResultCode = 50008;

    DECLARE @IdUsuario INT;
    DECLARE @Fechas TABLE
    (
        RowNum INT NOT NULL PRIMARY KEY
        , Fecha DATE NOT NULL
    );
    DECLARE @RowNum INT;
    DECLARE @MaxRowNum INT;
    DECLARE @Fecha DATE;
    DECLARE @ChildResultCode INT;

    BEGIN TRY
        SELECT
            @IdUsuario = u.Id
        FROM
            dbo.Usuario AS u
        WHERE
            (u.Username = N'UsuarioScripts');

        IF (@IdUsuario IS NULL)
        BEGIN
            SET @outResultCode = 50005;

            RETURN;
        END;

        INSERT INTO @Fechas
        (
            RowNum
            , Fecha
        )
        SELECT
            ROW_NUMBER() OVER (ORDER BY sub.Fecha ASC)
            , sub.Fecha
        FROM
        (
            SELECT DISTINCT
                FO.n.value(N'@Fecha', N'DATE') AS Fecha
            FROM
                @inXml.nodes(N'/Operaciones/FechaOperacion') AS FO (n)
        ) AS sub;

        SET @RowNum = 1;

        SELECT
            @MaxRowNum = MAX(f.RowNum)
        FROM
            @Fechas AS f;

        WHILE (@RowNum <= ISNULL(@MaxRowNum, 0))
        BEGIN
            SELECT
                @Fecha = f.Fecha
            FROM
                @Fechas AS f
            WHERE
                (f.RowNum = @RowNum);

            EXEC dbo.spSim_ProcesarFechaOperacion
                @inIdUsuario = @IdUsuario
                , @inIP = @inIP
                , @inXml = @inXml
                , @inFecha = @Fecha
                , @outResultCode = @ChildResultCode OUTPUT;

            SET @RowNum = @RowNum + 1;
        END;

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

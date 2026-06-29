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

CREATE OR ALTER PROCEDURE dbo.spSim_ProcesarEmpleadoDia
    @inIdUsuario INT
    , @inIP NVARCHAR(45)
    , @inIdEmpleado INT
    , @inValorDocumentoIdentidad NVARCHAR(50)
    , @inXml XML
    , @inFecha DATE
    , @inEsDiaCierre BIT
    , @inEsPrimerEmpleado BIT
    , @outResultCode INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    SET @outResultCode = 50008;

    DECLARE @SalarioXHora DECIMAL(12, 2);
    DECLARE @InicioSemana DATE;
    DECLARE @FinSemana DATE;
    DECLARE @IdSemanaPlanilla INT;
    DECLARE @IdMesPlanilla INT;
    DECLARE @IdPlanillaSemanaEmpleado INT;
    DECLARE @IdPlanillaMesEmpleado INT;
    DECLARE @CantidadSemanas INT;

    DECLARE @MarcaHoras TABLE
    (
        RowNum INT NOT NULL PRIMARY KEY
        , HoraEntrada DATETIME2(0) NOT NULL
        , HoraSalida DATETIME2(0) NOT NULL
        , TieneJornada BIT NOT NULL
        , Ordinarias INT NOT NULL
        , ExtraNormales INT NOT NULL
        , ExtraDobles INT NOT NULL
    );

    DECLARE @MovDia TABLE
    (
        Fase TINYINT NOT NULL
        , IdTipoMovimiento INT NOT NULL
        , IdTipoDeduccion INT NULL
        , CantidadHoras INT NULL
        , Monto DECIMAL(14, 2) NOT NULL
        , Signo INT NOT NULL
        , Porcentaje DECIMAL(12, 4) NULL
    );

    DECLARE @SaldoInicial DECIMAL(14, 2);
    DECLARE @SumCreditos DECIMAL(14, 2);
    DECLARE @SumDebitos DECIMAL(14, 2);
    DECLARE @SalarioBrutoSemana DECIMAL(14, 2);
    DECLARE @HorasOrd INT;
    DECLARE @HorasExtraN INT;
    DECLARE @HorasExtraD INT;
    DECLARE @CantidadMarcas INT;

    DECLARE @InicioSemanaSiguiente DATE;
    DECLARE @FinSemanaSiguiente DATE;
    DECLARE @IdSemanaPlanillaSiguiente INT;
    DECLARE @IdMesPlanillaSiguiente INT;
    DECLARE @IdPlanillaMesEmpleadoSiguiente INT;
    DECLARE @NumeroSemanaSiguiente INT;
    DECLARE @EOM DATE;
    DECLARE @DayIndexEOM INT;
    DECLARE @FechaFinMesSig DATE;
    DECLARE @AnioMesSig INT;
    DECLARE @MesMesSig INT;
    DECLARE @CantidadSemanasMesSig INT;

    DECLARE @Parametros NVARCHAR(MAX);
    DECLARE @BitacoraResultCode INT;

    BEGIN TRY
        SELECT
            @SalarioXHora = p.SalarioXHora
        FROM
            dbo.Empleado AS e
        INNER JOIN
            dbo.Puesto AS p
            ON (p.Id = e.IdPuesto)
        WHERE
            (e.Id = @inIdEmpleado);

        SET @InicioSemana =
            DATEADD(
                DAY
                , -((DATEDIFF(DAY, '19000101', @inFecha) % 7 + 3) % 7)
                , @inFecha
            );
        SET @FinSemana = DATEADD(DAY, 6, @InicioSemana);

        SELECT
            @IdSemanaPlanilla = sp.Id
            , @IdMesPlanilla = sp.IdMesPlanilla
        FROM
            dbo.SemanaPlanilla AS sp
        WHERE
            (sp.FechaInicio <= @inFecha)
            AND (sp.FechaFin >= @inFecha);

        IF (@IdSemanaPlanilla IS NULL) AND (@inEsDiaCierre = 0)
        BEGIN
            SET @outResultCode = 0;

            RETURN;
        END;

        ;WITH Marca AS
        (
            SELECT
                ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS RowNum
                , TRY_CONVERT(DATETIME2(0), T.c.value(N'@HoraEntrada', N'NVARCHAR(20)')) AS HoraEntrada
                , TRY_CONVERT(DATETIME2(0), T.c.value(N'@HoraSalida', N'NVARCHAR(20)')) AS HoraSalida
            FROM
                @inXml.nodes(N'/Operaciones/FechaOperacion') AS FO (n)
            CROSS APPLY
                n.nodes(N'MarcaAsistencia') AS T (c)
            WHERE
                (FO.n.value(N'@Fecha', N'DATE') = @inFecha)
                AND (
                    T.c.value(N'@ValorDocumentoIdentidad', N'NVARCHAR(50)')
                    = @inValorDocumentoIdentidad
                )
        )
        , MarcaJornada AS
        (
            SELECT
                mk.RowNum
                , mk.HoraEntrada
                , mk.HoraSalida
                , jor.IdTipoJornada
                , CASE
                    WHEN (jor.IdTipoJornada IS NULL) THEN NULL
                    ELSE
                        DATEADD(
                            DAY
                            , CASE WHEN (jor.CruzaMedianoche = 1) THEN 1 ELSE 0 END
                            , CAST(
                                CONCAT(
                                    CAST(CAST(mk.HoraEntrada AS DATE) AS NVARCHAR(10))
                                    , N' '
                                    , CAST(jor.HoraFin AS NVARCHAR(8))
                                )
                                AS DATETIME2(0)
                            )
                        )
                  END AS FinJornada
            FROM
                Marca AS mk
            OUTER APPLY
            (
                SELECT TOP (1)
                    j.IdTipoJornada
                    , tj.HoraFin
                    , tj.CruzaMedianoche
                FROM
                    dbo.JornadaEmpleadoSemana AS j
                INNER JOIN
                    dbo.TipoJornada AS tj
                    ON (tj.Id = j.IdTipoJornada)
                WHERE
                    (j.IdEmpleado = @inIdEmpleado)
                    AND (
                        j.FechaInicioSemana =
                            DATEADD(
                                DAY
                                , -((DATEDIFF(DAY, '19000101', CAST(mk.HoraEntrada AS DATE)) % 7 + 3) % 7)
                                , CAST(mk.HoraEntrada AS DATE)
                            )
                    )
            ) AS jor
        )
        , MarcaCalc AS
        (
            SELECT
                mj.RowNum
                , mj.HoraEntrada
                , mj.HoraSalida
                , mj.IdTipoJornada
                , mj.FinJornada
                , CASE
                    WHEN (mj.IdTipoJornada IS NULL) THEN 0
                    ELSE
                        CASE
                            WHEN (
                                DATEDIFF(
                                    MINUTE
                                    , mj.HoraEntrada
                                    , CASE
                                        WHEN (mj.HoraSalida < mj.FinJornada) THEN mj.HoraSalida
                                        ELSE mj.FinJornada
                                    END
                                ) / 60 < 0
                            ) THEN 0
                            ELSE
                                DATEDIFF(
                                    MINUTE
                                    , mj.HoraEntrada
                                    , CASE
                                        WHEN (mj.HoraSalida < mj.FinJornada) THEN mj.HoraSalida
                                        ELSE mj.FinJornada
                                    END
                                ) / 60
                        END
                  END AS Ordinarias
                , CASE
                    WHEN (mj.IdTipoJornada IS NULL) THEN 0
                    WHEN (mj.HoraSalida > mj.FinJornada) THEN
                        DATEDIFF(MINUTE, mj.FinJornada, mj.HoraSalida) / 60
                    ELSE 0
                  END AS ExtraTotal
            FROM
                MarcaJornada AS mj
        )
        , Tally AS
        (
            SELECT TOP (1000)
                ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) - 1 AS n
            FROM
                sys.all_objects
        )
        , ExtraClasif AS
        (
            SELECT
                mc.RowNum
                , SUM(
                    CASE
                        WHEN (
                            (DATEDIFF(DAY, '19000101', CAST(DATEADD(HOUR, t.n, mc.FinJornada) AS DATE)) % 7 = 6)
                            OR EXISTS
                            (
                                SELECT 1
                                FROM dbo.Feriado AS f
                                WHERE (f.Fecha = CAST(DATEADD(HOUR, t.n, mc.FinJornada) AS DATE))
                            )
                        ) THEN 1
                        ELSE 0
                    END
                  ) AS ExtraDobles
                , SUM(
                    CASE
                        WHEN (
                            (DATEDIFF(DAY, '19000101', CAST(DATEADD(HOUR, t.n, mc.FinJornada) AS DATE)) % 7 = 6)
                            OR EXISTS
                            (
                                SELECT 1
                                FROM dbo.Feriado AS f
                                WHERE (f.Fecha = CAST(DATEADD(HOUR, t.n, mc.FinJornada) AS DATE))
                            )
                        ) THEN 0
                        ELSE 1
                    END
                  ) AS ExtraNormales
            FROM
                MarcaCalc AS mc
            INNER JOIN
                Tally AS t
                ON (t.n < mc.ExtraTotal)
            GROUP BY
                mc.RowNum
        )
        INSERT INTO @MarcaHoras
        (
            RowNum
            , HoraEntrada
            , HoraSalida
            , TieneJornada
            , Ordinarias
            , ExtraNormales
            , ExtraDobles
        )
        SELECT
            mc.RowNum
            , mc.HoraEntrada
            , mc.HoraSalida
            , CASE WHEN (mc.IdTipoJornada IS NULL) THEN 0 ELSE 1 END
            , mc.Ordinarias
            , ISNULL(ec.ExtraNormales, 0)
            , ISNULL(ec.ExtraDobles, 0)
        FROM
            MarcaCalc AS mc
        LEFT JOIN
            ExtraClasif AS ec
            ON (ec.RowNum = mc.RowNum);

        SELECT
            @CantidadMarcas = COUNT(1)
        FROM
            @MarcaHoras;

        IF EXISTS
        (
            SELECT 1
            FROM @MarcaHoras AS mh
            WHERE (mh.TieneJornada = 0)
        )
        BEGIN
            SET @outResultCode = 50017;

            RETURN;
        END;

        BEGIN TRANSACTION;

        IF (@IdSemanaPlanilla IS NOT NULL)
        BEGIN
            IF NOT EXISTS
            (
                SELECT 1
                FROM dbo.PlanillaSemanaEmpleado AS pse
                WHERE (pse.IdSemanaPlanilla = @IdSemanaPlanilla)
                  AND (pse.IdEmpleado = @inIdEmpleado)
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
                    , @inIdEmpleado
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
                AND (pse.IdEmpleado = @inIdEmpleado);

            IF NOT EXISTS
            (
                SELECT 1
                FROM dbo.PlanillaMesEmpleado AS pme
                WHERE (pme.IdMesPlanilla = @IdMesPlanilla)
                  AND (pme.IdEmpleado = @inIdEmpleado)
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
                    , @inIdEmpleado
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
                AND (pme.IdEmpleado = @inIdEmpleado);
        END;

        IF (@IdPlanillaSemanaEmpleado IS NOT NULL)
        BEGIN

            INSERT INTO dbo.MarcaAsistencia
            (
                IdEmpleado
                , Fecha
                , HoraEntrada
                , HoraSalida
                , Procesada
            )
            SELECT
                @inIdEmpleado
                , CAST(mh.HoraEntrada AS DATE)
                , mh.HoraEntrada
                , mh.HoraSalida
                , 1
            FROM
                @MarcaHoras AS mh;

            ;WITH Agg AS
            (
                SELECT
                    ISNULL(SUM(mh.Ordinarias), 0) AS Ord
                    , ISNULL(SUM(mh.ExtraNormales), 0) AS ExN
                    , ISNULL(SUM(mh.ExtraDobles), 0) AS ExD
                FROM
                    @MarcaHoras AS mh
            )
            INSERT INTO @MovDia
            (
                Fase
                , IdTipoMovimiento
                , IdTipoDeduccion
                , CantidadHoras
                , Monto
                , Signo
                , Porcentaje
            )
            SELECT 0, 1, NULL, a.Ord, a.Ord * @SalarioXHora, 1, NULL
            FROM Agg AS a WHERE (a.Ord > 0)
            UNION ALL
            SELECT 0, 2, NULL, a.ExN, a.ExN * @SalarioXHora * 1.5, 1, NULL
            FROM Agg AS a WHERE (a.ExN > 0)
            UNION ALL
            SELECT 0, 3, NULL, a.ExD, a.ExD * @SalarioXHora * 2.0, 1, NULL
            FROM Agg AS a WHERE (a.ExD > 0);

            SELECT
                @SumCreditos = ISNULL(SUM(md.Monto), 0)
            FROM
                @MovDia AS md
            WHERE
                (md.Fase = 0);

            SELECT
                @SalarioBrutoSemana = pse.SalarioBruto
                , @SaldoInicial = pse.SalarioNeto
            FROM
                dbo.PlanillaSemanaEmpleado AS pse
            WHERE
                (pse.Id = @IdPlanillaSemanaEmpleado);

            SET @SalarioBrutoSemana = ISNULL(@SalarioBrutoSemana, 0) + @SumCreditos;

            IF (@inEsDiaCierre = 1)
            BEGIN
                SELECT
                    @CantidadSemanas = mp.CantidadSemanas
                FROM
                    dbo.MesPlanilla AS mp
                WHERE
                    (mp.Id = @IdMesPlanilla);

                INSERT INTO @MovDia
                (
                    Fase
                    , IdTipoMovimiento
                    , IdTipoDeduccion
                    , CantidadHoras
                    , Monto
                    , Signo
                    , Porcentaje
                )
                SELECT
                    1
                    , td.IdTipoMovimiento
                    , td.Id
                    , NULL
                    , CASE
                        WHEN (td.EsPorcentual = 1) THEN
                            ROUND(ed.PorcentajeOMonto * @SalarioBrutoSemana, 2)
                        ELSE
                            ROUND(ed.PorcentajeOMonto / @CantidadSemanas, 2)
                    END
                    , -1
                    , CASE
                        WHEN (td.EsPorcentual = 1) THEN ed.PorcentajeOMonto
                        ELSE NULL
                    END
                FROM
                    dbo.EmpleadoDeduccion AS ed
                INNER JOIN
                    dbo.TipoDeduccion AS td
                    ON (td.Id = ed.IdTipoDeduccion)
                WHERE
                    (ed.IdEmpleado = @inIdEmpleado)
                    AND (ed.EsActivo = 1)
                    AND (ed.FechaInicioVigencia <= @FinSemana)
                    AND (
                        (ed.FechaFinVigencia IS NULL)
                        OR (ed.FechaFinVigencia >= @FinSemana)
                    );
            END;

            SELECT
                @SumDebitos = ISNULL(SUM(md.Monto), 0)
            FROM
                @MovDia AS md
            WHERE
                (md.Fase = 1);

            IF EXISTS (SELECT 1 FROM @MovDia)
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
                    , NuevoSaldo
                    , IdPostByUser
                    , PostInIP
                )
                SELECT
                    @inIdEmpleado
                    , @IdPlanillaSemanaEmpleado
                    , md.IdTipoMovimiento
                    , md.IdTipoDeduccion
                    , @inFecha
                    , md.CantidadHoras
                    , md.Monto
                    , @SaldoInicial
                        + SUM(md.Signo * md.Monto) OVER
                          (
                              ORDER BY md.Fase, md.IdTipoMovimiento, ISNULL(md.IdTipoDeduccion, 0)
                              ROWS UNBOUNDED PRECEDING
                          )
                    , @inIdUsuario
                    , @inIP
                FROM
                    @MovDia AS md;

                SELECT
                    @HorasOrd = ISNULL(SUM(CASE WHEN (md.IdTipoMovimiento = 1) THEN md.CantidadHoras END), 0)
                    , @HorasExtraN = ISNULL(SUM(CASE WHEN (md.IdTipoMovimiento = 2) THEN md.CantidadHoras END), 0)
                    , @HorasExtraD = ISNULL(SUM(CASE WHEN (md.IdTipoMovimiento = 3) THEN md.CantidadHoras END), 0)
                FROM
                    @MovDia AS md
                WHERE
                    (md.Fase = 0);

                UPDATE
                    dbo.PlanillaSemanaEmpleado
                SET
                    SalarioBruto = SalarioBruto + @SumCreditos
                    , TotalDeducciones = TotalDeducciones + @SumDebitos
                    , SalarioNeto = @SaldoInicial + @SumCreditos - @SumDebitos
                    , CantidadHorasOrdinarias = CantidadHorasOrdinarias + @HorasOrd
                    , CantidadHorasExtraNormales = CantidadHorasExtraNormales + @HorasExtraN
                    , CantidadHorasExtraDobles = CantidadHorasExtraDobles + @HorasExtraD
                WHERE
                    (Id = @IdPlanillaSemanaEmpleado);

                UPDATE
                    dbo.PlanillaMesEmpleado
                SET
                    SalarioBrutoMensual = SalarioBrutoMensual + @SumCreditos
                    , TotalDeduccionesMensual = TotalDeduccionesMensual + @SumDebitos
                    , SalarioNetoMensual =
                        (SalarioBrutoMensual + @SumCreditos)
                        - (TotalDeduccionesMensual + @SumDebitos)
                WHERE
                    (Id = @IdPlanillaMesEmpleado);
            END;

            IF (@inEsDiaCierre = 1)
            BEGIN
                UPDATE
                    dem
                SET
                    MontoAcumulado = dem.MontoAcumulado + md.Monto
                FROM
                    dbo.DeduccionEmpleadoMes AS dem
                INNER JOIN
                    @MovDia AS md
                    ON (md.Fase = 1)
                    AND (md.IdTipoDeduccion = dem.IdTipoDeduccion)
                WHERE
                    (dem.IdPlanillaMesEmpleado = @IdPlanillaMesEmpleado);

                INSERT INTO dbo.DeduccionEmpleadoMes
                (
                    IdPlanillaMesEmpleado
                    , IdTipoDeduccion
                    , MontoAcumulado
                    , PorcentajeAplicado
                )
                SELECT
                    @IdPlanillaMesEmpleado
                    , md.IdTipoDeduccion
                    , md.Monto
                    , md.Porcentaje
                FROM
                    @MovDia AS md
                WHERE
                    (md.Fase = 1)
                    AND NOT EXISTS
                    (
                        SELECT 1
                        FROM dbo.DeduccionEmpleadoMes AS dem
                        WHERE (dem.IdPlanillaMesEmpleado = @IdPlanillaMesEmpleado)
                          AND (dem.IdTipoDeduccion = md.IdTipoDeduccion)
                    );
            END;

            IF (@CantidadMarcas > 0)
            BEGIN
                SET @Parametros =
                    N'{"idEmpleado":'
                    + CAST(@inIdEmpleado AS NVARCHAR(20))
                    + N',"fecha":"'
                    + CONVERT(NVARCHAR(10), @inFecha, 120)
                    + N'","marcas":'
                    + CAST(@CantidadMarcas AS NVARCHAR(10))
                    + N'}';

                EXEC dbo.spBitacora_RegistrarEvento
                    @inIdTipoEvento = 14
                    , @inIdUsuario = @inIdUsuario
                    , @inIP = @inIP
                    , @inParametros = @Parametros
                    , @inValoresAntes = NULL
                    , @inValoresDespues = NULL
                    , @outResultCode = @BitacoraResultCode OUTPUT;
            END;
        END;

        IF (@inEsDiaCierre = 1)
        BEGIN
            SET @InicioSemanaSiguiente = DATEADD(DAY, 1, @FinSemana);
            SET @FinSemanaSiguiente = DATEADD(DAY, 6, @InicioSemanaSiguiente);

            IF (@inEsPrimerEmpleado = 1)
            BEGIN

                IF NOT EXISTS
                (
                    SELECT 1
                    FROM dbo.MesPlanilla AS mp
                    WHERE (mp.FechaInicio <= @InicioSemanaSiguiente)
                      AND (mp.FechaFin >= @InicioSemanaSiguiente)
                )
                BEGIN
                    SET @EOM = EOMONTH(@InicioSemanaSiguiente);
                    SET @DayIndexEOM = DATEDIFF(DAY, '19000101', @EOM) % 7;
                    SET @FechaFinMesSig = DATEADD(DAY, -((@DayIndexEOM - 3 + 7) % 7), @EOM);

                    IF (@FechaFinMesSig < @InicioSemanaSiguiente)
                    BEGIN
                        SET @EOM = EOMONTH(DATEADD(MONTH, 1, @InicioSemanaSiguiente));
                        SET @DayIndexEOM = DATEDIFF(DAY, '19000101', @EOM) % 7;
                        SET @FechaFinMesSig = DATEADD(DAY, -((@DayIndexEOM - 3 + 7) % 7), @EOM);
                    END;

                    SET @AnioMesSig = YEAR(@FechaFinMesSig);
                    SET @MesMesSig = MONTH(@FechaFinMesSig);
                    SET @CantidadSemanasMesSig =
                        (DATEDIFF(DAY, @InicioSemanaSiguiente, @FechaFinMesSig) + 1) / 7;

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
                        @AnioMesSig
                        , @MesMesSig
                        , @InicioSemanaSiguiente
                        , @FechaFinMesSig
                        , @CantidadSemanasMesSig
                    );
                END;

                IF NOT EXISTS
                (
                    SELECT 1
                    FROM dbo.SemanaPlanilla AS sp
                    WHERE (sp.FechaInicio = @InicioSemanaSiguiente)
                )
                BEGIN
                    SELECT
                        @IdMesPlanillaSiguiente = mp.Id
                    FROM
                        dbo.MesPlanilla AS mp
                    WHERE
                        (mp.FechaInicio <= @InicioSemanaSiguiente)
                        AND (mp.FechaFin >= @InicioSemanaSiguiente);

                    SELECT
                        @NumeroSemanaSiguiente = COUNT(1) + 1
                    FROM
                        dbo.SemanaPlanilla AS sp
                    WHERE
                        (sp.IdMesPlanilla = @IdMesPlanillaSiguiente);

                    INSERT INTO dbo.SemanaPlanilla
                    (
                        IdMesPlanilla
                        , NumeroSemana
                        , FechaInicio
                        , FechaFin
                    )
                    VALUES
                    (
                        @IdMesPlanillaSiguiente
                        , @NumeroSemanaSiguiente
                        , @InicioSemanaSiguiente
                        , @FinSemanaSiguiente
                    );
                END;
            END;

            SELECT
                @IdSemanaPlanillaSiguiente = sp.Id
                , @IdMesPlanillaSiguiente = sp.IdMesPlanilla
            FROM
                dbo.SemanaPlanilla AS sp
            WHERE
                (sp.FechaInicio = @InicioSemanaSiguiente);

            IF (@IdSemanaPlanillaSiguiente IS NOT NULL)
                AND NOT EXISTS
                (
                    SELECT 1
                    FROM dbo.PlanillaSemanaEmpleado AS pse
                    WHERE (pse.IdSemanaPlanilla = @IdSemanaPlanillaSiguiente)
                      AND (pse.IdEmpleado = @inIdEmpleado)
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
                    @IdSemanaPlanillaSiguiente
                    , @inIdEmpleado
                    , 0
                    , 0
                    , 0
                    , 0
                    , 0
                    , 0
                );
            END;

            IF (@IdMesPlanillaSiguiente IS NOT NULL)
                AND (@IdMesPlanillaSiguiente <> ISNULL(@IdMesPlanilla, -1))
            BEGIN
                IF NOT EXISTS
                (
                    SELECT 1
                    FROM dbo.PlanillaMesEmpleado AS pme
                    WHERE (pme.IdMesPlanilla = @IdMesPlanillaSiguiente)
                      AND (pme.IdEmpleado = @inIdEmpleado)
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
                        @IdMesPlanillaSiguiente
                        , @inIdEmpleado
                        , 0
                        , 0
                        , 0
                    );
                END;

                SELECT
                    @IdPlanillaMesEmpleadoSiguiente = pme.Id
                FROM
                    dbo.PlanillaMesEmpleado AS pme
                WHERE
                    (pme.IdMesPlanilla = @IdMesPlanillaSiguiente)
                    AND (pme.IdEmpleado = @inIdEmpleado);

                INSERT INTO dbo.DeduccionEmpleadoMes
                (
                    IdPlanillaMesEmpleado
                    , IdTipoDeduccion
                    , MontoAcumulado
                    , PorcentajeAplicado
                )
                SELECT
                    @IdPlanillaMesEmpleadoSiguiente
                    , td.Id
                    , 0
                    , CASE
                        WHEN (td.EsPorcentual = 1) THEN ed.PorcentajeOMonto
                        ELSE NULL
                    END
                FROM
                    dbo.EmpleadoDeduccion AS ed
                INNER JOIN
                    dbo.TipoDeduccion AS td
                    ON (td.Id = ed.IdTipoDeduccion)
                WHERE
                    (ed.IdEmpleado = @inIdEmpleado)
                    AND (ed.EsActivo = 1)
                    AND NOT EXISTS
                    (
                        SELECT 1
                        FROM dbo.DeduccionEmpleadoMes AS dem
                        WHERE (dem.IdPlanillaMesEmpleado = @IdPlanillaMesEmpleadoSiguiente)
                          AND (dem.IdTipoDeduccion = td.Id)
                    );
            END;
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
    );
    DECLARE @AsignarJornada TABLE
    (
        RowNum INT NOT NULL PRIMARY KEY
        , ValorDocumentoIdentidad NVARCHAR(50) NOT NULL
        , Jornada NVARCHAR(50) NOT NULL
        , InicioSemana DATE NOT NULL
    );
    DECLARE @EmpleadosProcesar TABLE
    (
        RowNum INT NOT NULL PRIMARY KEY
        , IdEmpleado INT NOT NULL
        , ValorDocumentoIdentidad NVARCHAR(50) NOT NULL
    );

    DECLARE @InicioSemanaActual DATE;
    DECLARE @FinSemanaActual DATE;
    DECLARE @DayIndex INT;
    DECLARE @EsDiaCierre BIT;
    DECLARE @EsPrimerEmpleado BIT;
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
    DECLARE @IdEmpleado INT;
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

        UPDATE
            ma
        SET
            HoraEntrada = TRY_CONVERT(DATETIME2(0), ma.HoraEntradaStr)
            , HoraSalida = TRY_CONVERT(DATETIME2(0), ma.HoraSalidaStr)
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

        SET @DayIndex = DATEDIFF(DAY, '19000101', @inFecha) % 7;
        SET @EsDiaCierre =
            CASE
                WHEN (@DayIndex = 3) THEN 1
                ELSE 0
            END;

        SET @InicioSemanaActual =
            DATEADD(
                DAY
                , -((DATEDIFF(DAY, '19000101', @inFecha) % 7 + 3) % 7)
                , @inFecha
            );
        SET @FinSemanaActual = DATEADD(DAY, 6, @InicioSemanaActual);

        INSERT INTO @EmpleadosProcesar
        (
            RowNum
            , IdEmpleado
            , ValorDocumentoIdentidad
        )
        SELECT
            ROW_NUMBER() OVER (ORDER BY e.Id ASC)
            , e.Id
            , e.ValorDocumentoIdentidad
        FROM
            dbo.Empleado AS e
        WHERE
            (e.EsActivo = 1)
            AND (
                (@EsDiaCierre = 1)
                OR EXISTS
                (
                    SELECT
                        1
                    FROM
                        @MarcaAsistencia AS ma
                    WHERE
                        (ma.ValorDocumentoIdentidad = e.ValorDocumentoIdentidad)
                )
            );

        SET @RowNum = 1;

        SELECT
            @MaxRowNum = MAX(ep.RowNum)
        FROM
            @EmpleadosProcesar AS ep;

        WHILE (@RowNum <= ISNULL(@MaxRowNum, 0))
        BEGIN
            SELECT
                @IdEmpleado = ep.IdEmpleado
                , @ValorDocumentoIdentidad = ep.ValorDocumentoIdentidad
            FROM
                @EmpleadosProcesar AS ep
            WHERE
                (ep.RowNum = @RowNum);

            SET @EsPrimerEmpleado =
                CASE
                    WHEN (@RowNum = 1) THEN 1
                    ELSE 0
                END;

            EXEC dbo.spSim_ProcesarEmpleadoDia
                @inIdUsuario = @inIdUsuario
                , @inIP = @inIP
                , @inIdEmpleado = @IdEmpleado
                , @inValorDocumentoIdentidad = @ValorDocumentoIdentidad
                , @inXml = @inXml
                , @inFecha = @inFecha
                , @inEsDiaCierre = @EsDiaCierre
                , @inEsPrimerEmpleado = @EsPrimerEmpleado
                , @outResultCode = @ChildResultCode OUTPUT;

            SET @RowNum = @RowNum + 1;
        END;

        IF (@EsDiaCierre = 1)
        BEGIN
            UPDATE
                dbo.SemanaPlanilla
            SET
                EstaCerrada = 1
            WHERE
                (FechaInicio <= @inFecha)
                AND (FechaFin >= @inFecha);

            UPDATE
                dbo.MesPlanilla
            SET
                EstaCerrado = 1
            WHERE
                (FechaFin = @FinSemanaActual);
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

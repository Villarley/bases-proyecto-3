SET NOCOUNT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

USE planilla_obrera;
GO

CREATE OR ALTER PROCEDURE dbo.spEmpleado_Listar
    @inIdUsuario INT
    , @inIP NVARCHAR(45)
    , @outResultCode INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    SET @outResultCode = 50008;

    DECLARE @BitacoraResultCode INT;

    BEGIN TRY
        SELECT
            e.ValorDocumentoIdentidad
            , e.Nombre AS NombreEmpleado
            , p.Nombre AS NombrePuesto
        FROM
            dbo.Empleado AS e
        INNER JOIN
            dbo.Puesto AS p
            ON (p.Id = e.IdPuesto)
        WHERE
            (e.EsActivo = 1)
        ORDER BY
            e.Nombre ASC;

        EXEC dbo.spBitacora_RegistrarEvento
            @inIdTipoEvento = 3
            , @inIdUsuario = @inIdUsuario
            , @inIP = @inIP
            , @inParametros = NULL
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

CREATE OR ALTER PROCEDURE dbo.spEmpleado_ListarConFiltro
    @inIdUsuario INT
    , @inIP NVARCHAR(45)
    , @inFiltro NVARCHAR(300)
    , @outResultCode INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    SET @outResultCode = 50008;

    DECLARE @Parametros NVARCHAR(MAX);
    DECLARE @BitacoraResultCode INT;

    BEGIN TRY
        SELECT
            e.ValorDocumentoIdentidad
            , e.Nombre AS NombreEmpleado
            , p.Nombre AS NombrePuesto
        FROM
            dbo.Empleado AS e
        INNER JOIN
            dbo.Puesto AS p
            ON (p.Id = e.IdPuesto)
        WHERE
            (e.Nombre LIKE N'%' + @inFiltro + N'%')
            AND (e.EsActivo = 1)
        ORDER BY
            e.Nombre ASC;

        SET @Parametros =
            N'{"filtro":"'
            + STRING_ESCAPE(@inFiltro, 'json')
            + N'"}';

        EXEC dbo.spBitacora_RegistrarEvento
            @inIdTipoEvento = 4
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

CREATE OR ALTER PROCEDURE dbo.spEmpleado_Insertar
    @inIdUsuario INT
    , @inIP NVARCHAR(45)
    , @inNombre NVARCHAR(300)
    , @inValorDocumentoIdentidad NVARCHAR(50)
    , @inIdTipoDocumento INT
    , @inIdDepartamento INT
    , @inNombrePuesto NVARCHAR(200)
    , @inNumeroCuentaBanco NVARCHAR(50)
    , @inFechaIngreso DATE
    , @inUsername NVARCHAR(100)
    , @inPassword NVARCHAR(256)
    , @outResultCode INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    SET @outResultCode = 50008;

    DECLARE @IdTipoDocumento INT;
    DECLARE @IdDepartamento INT;
    DECLARE @IdPuesto INT;
    DECLARE @FechaIngreso DATE;
    DECLARE @IdUsuarioEmpleado INT;
    DECLARE @IdEmpleado INT;
    DECLARE @ValoresDespues NVARCHAR(MAX);
    DECLARE @BitacoraResultCode INT;

    BEGIN TRY
        SELECT
            @IdPuesto = p.Id
        FROM
            dbo.Puesto AS p
        WHERE
            (p.Nombre = @inNombrePuesto);

        IF (@IdPuesto IS NULL)
        BEGIN
            SET @outResultCode = 50006;

            RETURN;
        END;

        IF EXISTS
        (
            SELECT
                1
            FROM
                dbo.Empleado AS e
            WHERE
                (e.ValorDocumentoIdentidad = @inValorDocumentoIdentidad)
                AND (e.EsActivo = 1)
        )
        BEGIN
            SET @outResultCode = 50004;

            RETURN;
        END;

        IF (@inUsername IS NOT NULL)
        BEGIN
            IF EXISTS
            (
                SELECT
                    1
                FROM
                    dbo.Usuario AS u
                WHERE
                    (u.Username = @inUsername)
            )
            BEGIN
                SET @outResultCode = 50015;

                RETURN;
            END;
        END;

        SET @IdTipoDocumento = ISNULL(@inIdTipoDocumento, 1);
        SET @IdDepartamento = ISNULL(@inIdDepartamento, 1);
        SET @FechaIngreso = ISNULL(@inFechaIngreso, CAST(GETDATE() AS DATE));
        SET @IdUsuarioEmpleado = NULL;

        BEGIN TRANSACTION;

        IF (
            (@inUsername IS NOT NULL)
            AND (@inPassword IS NOT NULL)
        )
        BEGIN
            INSERT INTO dbo.Usuario
            (
                Username
                , Password
                , IdTipoUsuario
            )
            VALUES
            (
                @inUsername
                , @inPassword
                , 2
            );

            SET @IdUsuarioEmpleado = SCOPE_IDENTITY();
        END;

        INSERT INTO dbo.Empleado
        (
            IdUsuario
            , IdTipoDocumento
            , ValorDocumentoIdentidad
            , Nombre
            , IdDepartamento
            , IdPuesto
            , NumeroCuentaBanco
            , FechaIngreso
        )
        VALUES
        (
            @IdUsuarioEmpleado
            , @IdTipoDocumento
            , @inValorDocumentoIdentidad
            , @inNombre
            , @IdDepartamento
            , @IdPuesto
            , @inNumeroCuentaBanco
            , @FechaIngreso
        );

        SET @IdEmpleado = SCOPE_IDENTITY();

        SELECT
            @ValoresDespues = (
                SELECT
                    e.ValorDocumentoIdentidad
                    , e.Nombre
                    , p.Nombre AS NombrePuesto
                    , d.Nombre AS NombreDepartamento
                    , e.NumeroCuentaBanco
                    , e.FechaIngreso
                    , e.EsActivo
                FROM
                    dbo.Empleado AS e
                INNER JOIN
                    dbo.Puesto AS p
                    ON (p.Id = e.IdPuesto)
                INNER JOIN
                    dbo.Departamento AS d
                    ON (d.Id = e.IdDepartamento)
                WHERE
                    (e.Id = @IdEmpleado)
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
            );

        EXEC dbo.spBitacora_RegistrarEvento
            @inIdTipoEvento = 5
            , @inIdUsuario = @inIdUsuario
            , @inIP = @inIP
            , @inParametros = NULL
            , @inValoresAntes = NULL
            , @inValoresDespues = @ValoresDespues
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

CREATE OR ALTER PROCEDURE dbo.spEmpleado_Editar
    @inIdUsuario INT
    , @inIP NVARCHAR(45)
    , @inValorDocumentoIdentidad NVARCHAR(50)
    , @inNuevoNombre NVARCHAR(300)
    , @inNuevoValorDocumentoIdentidad NVARCHAR(50)
    , @inNombrePuesto NVARCHAR(200)
    , @inIdDepartamento INT
    , @inNumeroCuentaBanco NVARCHAR(50)
    , @outResultCode INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    SET @outResultCode = 50008;

    DECLARE @IdEmpleado INT;
    DECLARE @NombreActual NVARCHAR(300);
    DECLARE @ValorDocumentoActual NVARCHAR(50);
    DECLARE @IdPuestoActual INT;
    DECLARE @IdDepartamentoActual INT;
    DECLARE @NumeroCuentaBancoActual NVARCHAR(50);
    DECLARE @NuevoNombre NVARCHAR(300);
    DECLARE @NuevoValorDocumentoIdentidad NVARCHAR(50);
    DECLARE @IdPuestoFinal INT;
    DECLARE @IdDepartamentoFinal INT;
    DECLARE @NumeroCuentaBancoFinal NVARCHAR(50);
    DECLARE @ValoresAntes NVARCHAR(MAX);
    DECLARE @ValoresDespues NVARCHAR(MAX);
    DECLARE @BitacoraResultCode INT;

    BEGIN TRY
        SELECT
            @IdEmpleado = e.Id
            , @NombreActual = e.Nombre
            , @ValorDocumentoActual = e.ValorDocumentoIdentidad
            , @IdPuestoActual = e.IdPuesto
            , @IdDepartamentoActual = e.IdDepartamento
            , @NumeroCuentaBancoActual = e.NumeroCuentaBanco
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

        SET @NuevoNombre = ISNULL(@inNuevoNombre, @NombreActual);
        SET @NuevoValorDocumentoIdentidad =
            ISNULL(@inNuevoValorDocumentoIdentidad, @ValorDocumentoActual);
        SET @IdDepartamentoFinal = ISNULL(@inIdDepartamento, @IdDepartamentoActual);
        SET @NumeroCuentaBancoFinal =
            ISNULL(@inNumeroCuentaBanco, @NumeroCuentaBancoActual);

        IF (@inNombrePuesto IS NOT NULL)
        BEGIN
            SELECT
                @IdPuestoFinal = p.Id
            FROM
                dbo.Puesto AS p
            WHERE
                (p.Nombre = @inNombrePuesto);

            IF (@IdPuestoFinal IS NULL)
            BEGIN
                SET @outResultCode = 50006;

                RETURN;
            END;
        END
        ELSE
        BEGIN
            SET @IdPuestoFinal = @IdPuestoActual;
        END;

        IF (
            (@NuevoValorDocumentoIdentidad <> @ValorDocumentoActual)
            AND EXISTS
            (
                SELECT
                    1
                FROM
                    dbo.Empleado AS e
                WHERE
                    (e.ValorDocumentoIdentidad = @NuevoValorDocumentoIdentidad)
                    AND (e.EsActivo = 1)
                    AND (e.Id <> @IdEmpleado)
            )
        )
        BEGIN
            SET @outResultCode = 50004;

            RETURN;
        END;

        SELECT
            @ValoresAntes = (
                SELECT
                    e.ValorDocumentoIdentidad
                    , e.Nombre
                    , p.Nombre AS NombrePuesto
                    , d.Nombre AS NombreDepartamento
                    , e.NumeroCuentaBanco
                    , e.FechaIngreso
                    , e.EsActivo
                FROM
                    dbo.Empleado AS e
                INNER JOIN
                    dbo.Puesto AS p
                    ON (p.Id = e.IdPuesto)
                INNER JOIN
                    dbo.Departamento AS d
                    ON (d.Id = e.IdDepartamento)
                WHERE
                    (e.Id = @IdEmpleado)
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
            );

        SELECT
            @ValoresDespues = (
                SELECT
                    @NuevoValorDocumentoIdentidad AS ValorDocumentoIdentidad
                    , @NuevoNombre AS Nombre
                    , p.Nombre AS NombrePuesto
                    , d.Nombre AS NombreDepartamento
                    , @NumeroCuentaBancoFinal AS NumeroCuentaBanco
                    , e.FechaIngreso
                    , e.EsActivo
                FROM
                    dbo.Empleado AS e
                INNER JOIN
                    dbo.Puesto AS p
                    ON (p.Id = @IdPuestoFinal)
                INNER JOIN
                    dbo.Departamento AS d
                    ON (d.Id = @IdDepartamentoFinal)
                WHERE
                    (e.Id = @IdEmpleado)
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
            );

        BEGIN TRANSACTION;

        UPDATE
            dbo.Empleado
        SET
            Nombre = @NuevoNombre
            , ValorDocumentoIdentidad = @NuevoValorDocumentoIdentidad
            , IdPuesto = @IdPuestoFinal
            , IdDepartamento = @IdDepartamentoFinal
            , NumeroCuentaBanco = @NumeroCuentaBancoFinal
        WHERE
            (Id = @IdEmpleado);

        EXEC dbo.spBitacora_RegistrarEvento
            @inIdTipoEvento = 11
            , @inIdUsuario = @inIdUsuario
            , @inIP = @inIP
            , @inParametros = NULL
            , @inValoresAntes = @ValoresAntes
            , @inValoresDespues = @ValoresDespues
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

CREATE OR ALTER PROCEDURE dbo.spEmpleado_Eliminar
    @inIdUsuario INT
    , @inIP NVARCHAR(45)
    , @inValorDocumentoIdentidad NVARCHAR(50)
    , @inFechaSalida DATE
    , @outResultCode INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    SET @outResultCode = 50008;

    DECLARE @IdEmpleado INT;
    DECLARE @IdUsuarioEmpleado INT;
    DECLARE @FechaSalida DATE;
    DECLARE @ValoresAntes NVARCHAR(MAX);
    DECLARE @BitacoraResultCode INT;

    BEGIN TRY
        SELECT
            @IdEmpleado = e.Id
            , @IdUsuarioEmpleado = e.IdUsuario
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

        SET @FechaSalida = ISNULL(@inFechaSalida, CAST(GETDATE() AS DATE));

        SELECT
            @ValoresAntes = (
                SELECT
                    e.ValorDocumentoIdentidad
                    , e.Nombre
                    , p.Nombre AS NombrePuesto
                    , d.Nombre AS NombreDepartamento
                    , e.NumeroCuentaBanco
                    , e.FechaIngreso
                    , e.EsActivo
                FROM
                    dbo.Empleado AS e
                INNER JOIN
                    dbo.Puesto AS p
                    ON (p.Id = e.IdPuesto)
                INNER JOIN
                    dbo.Departamento AS d
                    ON (d.Id = e.IdDepartamento)
                WHERE
                    (e.Id = @IdEmpleado)
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
            );

        BEGIN TRANSACTION;

        UPDATE
            dbo.Empleado
        SET
            EsActivo = 0
            , FechaSalida = @FechaSalida
        WHERE
            (Id = @IdEmpleado);

        UPDATE
            dbo.EmpleadoDeduccion
        SET
            EsActivo = 0
            , FechaFinVigencia = @FechaSalida
        WHERE
            (IdEmpleado = @IdEmpleado)
            AND (EsActivo = 1);

        IF (@IdUsuarioEmpleado IS NOT NULL)
        BEGIN
            UPDATE
                dbo.Usuario
            SET
                EsActivo = 0
            WHERE
                (Id = @IdUsuarioEmpleado);
        END;

        EXEC dbo.spBitacora_RegistrarEvento
            @inIdTipoEvento = 6
            , @inIdUsuario = @inIdUsuario
            , @inIP = @inIP
            , @inParametros = NULL
            , @inValoresAntes = @ValoresAntes
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

CREATE OR ALTER PROCEDURE dbo.spEmpleado_Impersonar
    @inIdUsuarioAdmin INT
    , @inIP NVARCHAR(45)
    , @inValorDocumentoIdentidad NVARCHAR(50)
    , @outResultCode INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    SET @outResultCode = 50008;

    DECLARE @IdEmpleado INT;
    DECLARE @Parametros NVARCHAR(MAX);
    DECLARE @BitacoraResultCode INT;

    BEGIN TRY
        IF NOT EXISTS
        (
            SELECT
                1
            FROM
                dbo.Usuario AS u
            WHERE
                (u.Id = @inIdUsuarioAdmin)
                AND (u.EsActivo = 1)
                AND (u.IdTipoUsuario = 1)
        )
        BEGIN
            SET @outResultCode = 50014;

            RETURN;
        END;

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

        SET @Parametros =
            N'{"idEmpleado":'
            + CAST(@IdEmpleado AS NVARCHAR(20))
            + N'}';

        EXEC dbo.spBitacora_RegistrarEvento
            @inIdTipoEvento = 12
            , @inIdUsuario = @inIdUsuarioAdmin
            , @inIP = @inIP
            , @inParametros = @Parametros
            , @inValoresAntes = NULL
            , @inValoresDespues = NULL
            , @outResultCode = @BitacoraResultCode OUTPUT;

        SELECT
            e.ValorDocumentoIdentidad
            , e.Nombre AS NombreEmpleado
            , p.Nombre AS NombrePuesto
        FROM
            dbo.Empleado AS e
        INNER JOIN
            dbo.Puesto AS p
            ON (p.Id = e.IdPuesto)
        WHERE
            (e.Id = @IdEmpleado);

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

CREATE OR ALTER PROCEDURE dbo.spEmpleado_RegresarAdmin
    @inIdUsuario INT
    , @inIP NVARCHAR(45)
    , @outResultCode INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    SET @outResultCode = 50008;

    DECLARE @BitacoraResultCode INT;

    BEGIN TRY
        IF NOT EXISTS
        (
            SELECT
                1
            FROM
                dbo.Usuario AS u
            WHERE
                (u.Id = @inIdUsuario)
        )
        BEGIN
            SET @outResultCode = 50005;

            RETURN;
        END;

        EXEC dbo.spBitacora_RegistrarEvento
            @inIdTipoEvento = 13
            , @inIdUsuario = @inIdUsuario
            , @inIP = @inIP
            , @inParametros = NULL
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

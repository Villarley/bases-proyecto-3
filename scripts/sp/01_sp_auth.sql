SET NOCOUNT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

USE planilla_obrera;
GO

CREATE OR ALTER PROCEDURE dbo.spAuth_Login
    @inUsername NVARCHAR(100)
    , @inPassword NVARCHAR(256)
    , @inIP NVARCHAR(45)
    , @outIdUsuario INT OUTPUT
    , @outIdTipoUsuario INT OUTPUT
    , @outIdEmpleado INT OUTPUT
    , @outResultCode INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    SET @outResultCode = 50008;
    SET @outIdUsuario = NULL;
    SET @outIdTipoUsuario = NULL;
    SET @outIdEmpleado = NULL;

    DECLARE @IdUsuario INT;
    DECLARE @IdTipoUsuario INT;
    DECLARE @PasswordAlmacenado NVARCHAR(256);
    DECLARE @Resultado NVARCHAR(20) = N'no exitoso';
    DECLARE @Parametros NVARCHAR(MAX);
    DECLARE @BitacoraResultCode INT;

    BEGIN TRY
        SELECT
            @IdUsuario = u.Id
            , @IdTipoUsuario = u.IdTipoUsuario
            , @PasswordAlmacenado = u.Password
        FROM
            dbo.Usuario AS u
        WHERE
            (u.Username = @inUsername)
            AND (u.EsActivo = 1);

        IF (@IdUsuario IS NULL)
        BEGIN
            SET @outResultCode = 50001;
        END
        ELSE IF (@PasswordAlmacenado <> @inPassword)
        BEGIN
            SET @outResultCode = 50002;
        END
        ELSE
        BEGIN
            SET @outIdUsuario = @IdUsuario;
            SET @outIdTipoUsuario = @IdTipoUsuario;
            SET @Resultado = N'exitoso';
            SET @outResultCode = 0;

            SELECT
                @outIdEmpleado = e.Id
            FROM
                dbo.Empleado AS e
            WHERE
                (e.IdUsuario = @outIdUsuario)
                AND (e.EsActivo = 1);
        END;

        SET @Parametros =
            N'{"username":"'
            + STRING_ESCAPE(@inUsername, 'json')
            + N'","resultado":"'
            + @Resultado
            + N'"}';

        EXEC dbo.spBitacora_RegistrarEvento
            @inIdTipoEvento = 1
            , @inIdUsuario = @IdUsuario
            , @inIP = @inIP
            , @inParametros = @Parametros
            , @inValoresAntes = NULL
            , @inValoresDespues = NULL
            , @outResultCode = @BitacoraResultCode OUTPUT;
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

CREATE OR ALTER PROCEDURE dbo.spAuth_Logout
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
            @inIdTipoEvento = 2
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

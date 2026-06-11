SET NOCOUNT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

USE planilla_obrera;
GO

CREATE OR ALTER PROCEDURE dbo.spBitacora_RegistrarEvento
    @inIdTipoEvento INT
    , @inIdUsuario INT
    , @inIP NVARCHAR(45)
    , @inParametros NVARCHAR(MAX)
    , @inValoresAntes NVARCHAR(MAX)
    , @inValoresDespues NVARCHAR(MAX)
    , @outResultCode INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    SET @outResultCode = 50008;

    BEGIN TRY
        IF NOT EXISTS
        (
            SELECT
                1
            FROM
                dbo.TipoEvento AS te
            WHERE
                (te.Id = @inIdTipoEvento)
        )
        BEGIN
            SET @outResultCode = 50016;

            RETURN;
        END;

        INSERT INTO dbo.BitacoraEvento
        (
            IdTipoEvento
            , IdUsuario
            , IP
            , Parametros
            , ValoresAntes
            , ValoresDespues
        )
        VALUES
        (
            @inIdTipoEvento
            , @inIdUsuario
            , @inIP
            , @inParametros
            , @inValoresAntes
            , @inValoresDespues
        );

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

CREATE OR ALTER PROCEDURE dbo.spError_ObtenerPorCodigo
    @inCodigo INT
    , @outDescripcion NVARCHAR(1000) OUTPUT
    , @outResultCode INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    SET @outResultCode = 50008;
    SET @outDescripcion = NULL;

    BEGIN TRY
        SELECT
            @outDescripcion = e.Descripcion
        FROM
            dbo.Error AS e
        WHERE
            (e.Codigo = @inCodigo);

        IF (@outDescripcion IS NULL)
        BEGIN
            SET @outDescripcion = N'Error desconocido';
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

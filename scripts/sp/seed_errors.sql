SET NOCOUNT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

USE planilla_obrera;
GO

DELETE FROM dbo.Error;

INSERT INTO dbo.Error
(
    Codigo
    , Descripcion
)
VALUES
(
    50001
    , N'Login: usuario no existe o esta inactivo'
)
, (
    50002
    , N'Login: password incorrecto'
)
, (
    50003
    , N'Empleado no existe'
)
, (
    50004
    , N'Ya existe un empleado activo con ese documento de identidad'
)
, (
    50005
    , N'Usuario no existe'
)
, (
    50006
    , N'Puesto no existe (mapeo por nombre fallido)'
)
, (
    50007
    , N'Tipo de deduccion no existe'
)
, (
    50008
    , N'Error de base de datos (error interno)'
)
, (
    50009
    , N'La deduccion ya esta asociada al empleado'
)
, (
    50010
    , N'La deduccion no esta asociada al empleado'
)
, (
    50011
    , N'Tipo de jornada no existe'
)
, (
    50012
    , N'Semana de planilla no existe'
)
, (
    50013
    , N'Mes de planilla no existe'
)
, (
    50014
    , N'Usuario sin privilegios para la operacion'
)
, (
    50015
    , N'Parametros invalidos'
)
, (
    50016
    , N'Tipo de evento no existe'
)
, (
    50017
    , N'Empleado sin jornada asignada para la semana'
)
, (
    50018
    , N'Semana de planilla no aperturada'
);
GO

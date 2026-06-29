IF DB_ID(N'planilla_obrera') IS NULL
BEGIN
    CREATE DATABASE planilla_obrera;
END;
GO

USE planilla_obrera;
GO

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'dbo.Movimiento', N'U') IS NOT NULL
    DROP TABLE dbo.Movimiento;
GO

IF OBJECT_ID(N'dbo.BitacoraEvento', N'U') IS NOT NULL
    DROP TABLE dbo.BitacoraEvento;
GO

IF OBJECT_ID(N'dbo.MarcaAsistencia', N'U') IS NOT NULL
    DROP TABLE dbo.MarcaAsistencia;
GO

IF OBJECT_ID(N'dbo.JornadaEmpleadoSemana', N'U') IS NOT NULL
    DROP TABLE dbo.JornadaEmpleadoSemana;
GO

IF OBJECT_ID(N'dbo.EmpleadoDeduccion', N'U') IS NOT NULL
    DROP TABLE dbo.EmpleadoDeduccion;
GO

IF OBJECT_ID(N'dbo.DeduccionEmpleadoMes', N'U') IS NOT NULL
    DROP TABLE dbo.DeduccionEmpleadoMes;
GO

IF OBJECT_ID(N'dbo.PlanillaSemanaEmpleado', N'U') IS NOT NULL
    DROP TABLE dbo.PlanillaSemanaEmpleado;
GO

IF OBJECT_ID(N'dbo.PlanillaMesEmpleado', N'U') IS NOT NULL
    DROP TABLE dbo.PlanillaMesEmpleado;
GO

IF OBJECT_ID(N'dbo.SemanaPlanilla', N'U') IS NOT NULL
    DROP TABLE dbo.SemanaPlanilla;
GO

IF OBJECT_ID(N'dbo.MesPlanilla', N'U') IS NOT NULL
    DROP TABLE dbo.MesPlanilla;
GO

IF OBJECT_ID(N'dbo.Empleado', N'U') IS NOT NULL
    DROP TABLE dbo.Empleado;
GO

IF OBJECT_ID(N'dbo.DBError', N'U') IS NOT NULL
    DROP TABLE dbo.DBError;
GO

IF OBJECT_ID(N'dbo.Error', N'U') IS NOT NULL
    DROP TABLE dbo.Error;
GO

IF OBJECT_ID(N'dbo.Usuario', N'U') IS NOT NULL
    DROP TABLE dbo.Usuario;
GO

IF OBJECT_ID(N'dbo.TipoDeduccion', N'U') IS NOT NULL
    DROP TABLE dbo.TipoDeduccion;
GO

IF OBJECT_ID(N'dbo.TipoMovimiento', N'U') IS NOT NULL
    DROP TABLE dbo.TipoMovimiento;
GO

IF OBJECT_ID(N'dbo.Feriado', N'U') IS NOT NULL
    DROP TABLE dbo.Feriado;
GO

IF OBJECT_ID(N'dbo.TipoJornada', N'U') IS NOT NULL
    DROP TABLE dbo.TipoJornada;
GO

IF OBJECT_ID(N'dbo.TipoDocumentoIdentidad', N'U') IS NOT NULL
    DROP TABLE dbo.TipoDocumentoIdentidad;
GO

IF OBJECT_ID(N'dbo.Departamento', N'U') IS NOT NULL
    DROP TABLE dbo.Departamento;
GO

IF OBJECT_ID(N'dbo.Puesto', N'U') IS NOT NULL
    DROP TABLE dbo.Puesto;
GO

IF OBJECT_ID(N'dbo.TipoEvento', N'U') IS NOT NULL
    DROP TABLE dbo.TipoEvento;
GO

IF OBJECT_ID(N'dbo.TipoUsuario', N'U') IS NOT NULL
    DROP TABLE dbo.TipoUsuario;
GO

/* ------------------------------------------------------------------ */
/* Catálogos                                                          */
/* ------------------------------------------------------------------ */

CREATE TABLE dbo.TipoDocumentoIdentidad
(
    Id INT NOT NULL
    , Nombre NVARCHAR(100) NOT NULL
    , CONSTRAINT PK_TipoDocumentoIdentidad PRIMARY KEY CLUSTERED (Id)
);
GO

CREATE TABLE dbo.Departamento
(
    Id INT NOT NULL
    , Nombre NVARCHAR(150) NOT NULL
    , CONSTRAINT PK_Departamento PRIMARY KEY CLUSTERED (Id)
);
GO

CREATE TABLE dbo.Puesto
(
    Id INT IDENTITY(1, 1) NOT NULL
    , Nombre NVARCHAR(200) NOT NULL
    , SalarioXHora DECIMAL(12, 2) NOT NULL
    , CONSTRAINT PK_Puesto PRIMARY KEY CLUSTERED (Id)
    , CONSTRAINT UQ_Puesto_Nombre UNIQUE (Nombre)
);
GO

CREATE TABLE dbo.TipoJornada
(
    Id INT NOT NULL
    , Nombre NVARCHAR(50) NOT NULL
    , HoraInicio TIME(0) NOT NULL
    , HoraFin TIME(0) NOT NULL
    , DuracionHoras INT NOT NULL
        CONSTRAINT DF_TipoJornada_DuracionHoras DEFAULT (8)
    , CruzaMedianoche BIT NOT NULL
        CONSTRAINT DF_TipoJornada_CruzaMedianoche DEFAULT (0)
    , CONSTRAINT PK_TipoJornada PRIMARY KEY CLUSTERED (Id)
);
GO

CREATE TABLE dbo.Feriado
(
    Id INT NOT NULL
    , Nombre NVARCHAR(150) NOT NULL
    , Fecha DATE NOT NULL
    , CONSTRAINT PK_Feriado PRIMARY KEY CLUSTERED (Id)
    , CONSTRAINT UQ_Feriado_Fecha UNIQUE (Fecha)
);
GO

CREATE TABLE dbo.TipoMovimiento
(
    Id INT NOT NULL
    , Nombre NVARCHAR(150) NOT NULL
    , Accion CHAR(1) NOT NULL
    , CONSTRAINT PK_TipoMovimiento PRIMARY KEY CLUSTERED (Id)
    , CONSTRAINT CK_TipoMovimiento_Accion CHECK (Accion IN ('+', '-'))
);
GO

CREATE TABLE dbo.TipoDeduccion
(
    Id INT NOT NULL
    , Nombre NVARCHAR(150) NULL
    , EsObligatorio BIT NOT NULL
        CONSTRAINT DF_TipoDeduccion_EsObligatorio DEFAULT (0)
    , EsPorcentual BIT NOT NULL
        CONSTRAINT DF_TipoDeduccion_EsPorcentual DEFAULT (0)
    , ValorPorDefecto DECIMAL(12, 4) NOT NULL
        CONSTRAINT DF_TipoDeduccion_ValorPorDefecto DEFAULT (0)
    , IdTipoMovimiento INT NOT NULL
    , CONSTRAINT PK_TipoDeduccion PRIMARY KEY CLUSTERED (Id)
    , CONSTRAINT FK_TipoDeduccion_TipoMovimiento FOREIGN KEY (IdTipoMovimiento) REFERENCES dbo.TipoMovimiento (Id)
);
GO

CREATE TABLE dbo.TipoEvento
(
    Id INT NOT NULL
    , Nombre NVARCHAR(150) NOT NULL
    , CONSTRAINT PK_TipoEvento PRIMARY KEY CLUSTERED (Id)
);
GO

CREATE TABLE dbo.TipoUsuario
(
    Id INT NOT NULL
    , Nombre NVARCHAR(50) NOT NULL
    , CONSTRAINT PK_TipoUsuario PRIMARY KEY CLUSTERED (Id)
);
GO

/* ------------------------------------------------------------------ */
/* Núcleo                                                             */
/* ------------------------------------------------------------------ */

CREATE TABLE dbo.Usuario
(
    Id INT IDENTITY(1, 1) NOT NULL
    , Username NVARCHAR(100) NOT NULL
    , Password NVARCHAR(256) NOT NULL
    , IdTipoUsuario INT NOT NULL
    , EsActivo BIT NOT NULL
        CONSTRAINT DF_Usuario_EsActivo DEFAULT (1)
    , CONSTRAINT PK_Usuario PRIMARY KEY CLUSTERED (Id)
    , CONSTRAINT UQ_Usuario_Username UNIQUE (Username)
    , CONSTRAINT FK_Usuario_TipoUsuario FOREIGN KEY (IdTipoUsuario) REFERENCES dbo.TipoUsuario (Id)
);
GO

CREATE TABLE dbo.Empleado
(
    Id INT IDENTITY(1, 1) NOT NULL
    , IdUsuario INT NULL
    , IdTipoDocumento INT NOT NULL
    , ValorDocumentoIdentidad NVARCHAR(50) NOT NULL
    , Nombre NVARCHAR(300) NOT NULL
    , IdDepartamento INT NOT NULL
    , IdPuesto INT NOT NULL
    , NumeroCuentaBanco NVARCHAR(50) NULL
    , FechaIngreso DATE NOT NULL
    , FechaSalida DATE NULL
    , EsActivo BIT NOT NULL
        CONSTRAINT DF_Empleado_EsActivo DEFAULT (1)
    , CONSTRAINT PK_Empleado PRIMARY KEY CLUSTERED (Id)
    , CONSTRAINT FK_Empleado_Usuario FOREIGN KEY (IdUsuario) REFERENCES dbo.Usuario (Id)
    , CONSTRAINT FK_Empleado_TipoDocumentoIdentidad FOREIGN KEY (IdTipoDocumento) REFERENCES dbo.TipoDocumentoIdentidad (Id)
    , CONSTRAINT FK_Empleado_Departamento FOREIGN KEY (IdDepartamento) REFERENCES dbo.Departamento (Id)
    , CONSTRAINT FK_Empleado_Puesto FOREIGN KEY (IdPuesto) REFERENCES dbo.Puesto (Id)
);
GO

CREATE UNIQUE INDEX UQ_Empleado_IdUsuario
ON dbo.Empleado (IdUsuario)
WHERE (IdUsuario IS NOT NULL);
GO

CREATE UNIQUE INDEX UQ_Empleado_Documento_Activo
ON dbo.Empleado (ValorDocumentoIdentidad)
WHERE (EsActivo = 1);
GO

/* ------------------------------------------------------------------ */
/* Ciclo de planilla                                                  */
/* ------------------------------------------------------------------ */

CREATE TABLE dbo.MesPlanilla
(
    Id INT IDENTITY(1, 1) NOT NULL
    , Anio INT NOT NULL
    , Mes INT NOT NULL
    , FechaInicio DATE NOT NULL
    , FechaFin DATE NOT NULL
    , CantidadSemanas INT NOT NULL
    , EstaCerrado BIT NOT NULL
        CONSTRAINT DF_MesPlanilla_EstaCerrado DEFAULT (0)
    , CONSTRAINT PK_MesPlanilla PRIMARY KEY CLUSTERED (Id)
    , CONSTRAINT UQ_MesPlanilla_AnioMes UNIQUE (Anio, Mes)
);
GO

CREATE TABLE dbo.SemanaPlanilla
(
    Id INT IDENTITY(1, 1) NOT NULL
    , IdMesPlanilla INT NOT NULL
    , NumeroSemana INT NOT NULL
    , FechaInicio DATE NOT NULL
    , FechaFin DATE NOT NULL
    , EstaCerrada BIT NOT NULL
        CONSTRAINT DF_SemanaPlanilla_EstaCerrada DEFAULT (0)
    , CONSTRAINT PK_SemanaPlanilla PRIMARY KEY CLUSTERED (Id)
    , CONSTRAINT UQ_SemanaPlanilla_FechaInicio UNIQUE (FechaInicio)
    , CONSTRAINT FK_SemanaPlanilla_MesPlanilla FOREIGN KEY (IdMesPlanilla) REFERENCES dbo.MesPlanilla (Id)
);
GO

CREATE TABLE dbo.PlanillaMesEmpleado
(
    Id INT IDENTITY(1, 1) NOT NULL
    , IdMesPlanilla INT NOT NULL
    , IdEmpleado INT NOT NULL
    , SalarioBrutoMensual DECIMAL(14, 2) NOT NULL
        CONSTRAINT DF_PlanillaMesEmpleado_SalarioBrutoMensual DEFAULT (0)
    , TotalDeduccionesMensual DECIMAL(14, 2) NOT NULL
        CONSTRAINT DF_PlanillaMesEmpleado_TotalDeduccionesMensual DEFAULT (0)
    , SalarioNetoMensual DECIMAL(14, 2) NOT NULL
        CONSTRAINT DF_PlanillaMesEmpleado_SalarioNetoMensual DEFAULT (0)
    , CONSTRAINT PK_PlanillaMesEmpleado PRIMARY KEY CLUSTERED (Id)
    , CONSTRAINT UQ_PlanillaMesEmpleado UNIQUE (IdMesPlanilla, IdEmpleado)
    , CONSTRAINT FK_PlanillaMesEmpleado_MesPlanilla FOREIGN KEY (IdMesPlanilla) REFERENCES dbo.MesPlanilla (Id)
    , CONSTRAINT FK_PlanillaMesEmpleado_Empleado FOREIGN KEY (IdEmpleado) REFERENCES dbo.Empleado (Id)
);
GO

CREATE TABLE dbo.PlanillaSemanaEmpleado
(
    Id INT IDENTITY(1, 1) NOT NULL
    , IdSemanaPlanilla INT NOT NULL
    , IdEmpleado INT NOT NULL
    , SalarioBruto DECIMAL(14, 2) NOT NULL
        CONSTRAINT DF_PlanillaSemanaEmpleado_SalarioBruto DEFAULT (0)
    , TotalDeducciones DECIMAL(14, 2) NOT NULL
        CONSTRAINT DF_PlanillaSemanaEmpleado_TotalDeducciones DEFAULT (0)
    , SalarioNeto DECIMAL(14, 2) NOT NULL
        CONSTRAINT DF_PlanillaSemanaEmpleado_SalarioNeto DEFAULT (0)
    , CantidadHorasOrdinarias INT NOT NULL
        CONSTRAINT DF_PlanillaSemanaEmpleado_CantidadHorasOrdinarias DEFAULT (0)
    , CantidadHorasExtraNormales INT NOT NULL
        CONSTRAINT DF_PlanillaSemanaEmpleado_CantidadHorasExtraNormales DEFAULT (0)
    , CantidadHorasExtraDobles INT NOT NULL
        CONSTRAINT DF_PlanillaSemanaEmpleado_CantidadHorasExtraDobles DEFAULT (0)
    , CONSTRAINT PK_PlanillaSemanaEmpleado PRIMARY KEY CLUSTERED (Id)
    , CONSTRAINT UQ_PlanillaSemanaEmpleado UNIQUE (IdSemanaPlanilla, IdEmpleado)
    , CONSTRAINT FK_PlanillaSemanaEmpleado_SemanaPlanilla FOREIGN KEY (IdSemanaPlanilla) REFERENCES dbo.SemanaPlanilla (Id)
    , CONSTRAINT FK_PlanillaSemanaEmpleado_Empleado FOREIGN KEY (IdEmpleado) REFERENCES dbo.Empleado (Id)
);
GO

CREATE TABLE dbo.DeduccionEmpleadoMes
(
    Id INT IDENTITY(1, 1) NOT NULL
    , IdPlanillaMesEmpleado INT NOT NULL
    , IdTipoDeduccion INT NOT NULL
    , MontoAcumulado DECIMAL(14, 2) NOT NULL
        CONSTRAINT DF_DeduccionEmpleadoMes_MontoAcumulado DEFAULT (0)
    , PorcentajeAplicado DECIMAL(12, 4) NULL
    , CONSTRAINT PK_DeduccionEmpleadoMes PRIMARY KEY CLUSTERED (Id)
    , CONSTRAINT UQ_DeduccionEmpleadoMes UNIQUE (IdPlanillaMesEmpleado, IdTipoDeduccion)
    , CONSTRAINT FK_DeduccionEmpleadoMes_PlanillaMesEmpleado FOREIGN KEY (IdPlanillaMesEmpleado) REFERENCES dbo.PlanillaMesEmpleado (Id)
    , CONSTRAINT FK_DeduccionEmpleadoMes_TipoDeduccion FOREIGN KEY (IdTipoDeduccion) REFERENCES dbo.TipoDeduccion (Id)
);
GO

/* ------------------------------------------------------------------ */
/* Asociaciones                                                       */
/* ------------------------------------------------------------------ */

CREATE TABLE dbo.EmpleadoDeduccion
(
    Id INT IDENTITY(1, 1) NOT NULL
    , IdEmpleado INT NOT NULL
    , IdTipoDeduccion INT NOT NULL
    , PorcentajeOMonto DECIMAL(12, 4) NOT NULL
    , FechaInicioVigencia DATE NOT NULL
    , FechaFinVigencia DATE NULL
    , EsActivo BIT NOT NULL
        CONSTRAINT DF_EmpleadoDeduccion_EsActivo DEFAULT (1)
    , CONSTRAINT PK_EmpleadoDeduccion PRIMARY KEY CLUSTERED (Id)
    , CONSTRAINT FK_EmpleadoDeduccion_Empleado FOREIGN KEY (IdEmpleado) REFERENCES dbo.Empleado (Id)
    , CONSTRAINT FK_EmpleadoDeduccion_TipoDeduccion FOREIGN KEY (IdTipoDeduccion) REFERENCES dbo.TipoDeduccion (Id)
);
GO

CREATE UNIQUE INDEX UQ_EmpleadoDeduccion_Activa
ON dbo.EmpleadoDeduccion (IdEmpleado, IdTipoDeduccion)
WHERE (EsActivo = 1);
GO

CREATE TABLE dbo.JornadaEmpleadoSemana
(
    Id INT IDENTITY(1, 1) NOT NULL
    , IdEmpleado INT NOT NULL
    , IdTipoJornada INT NOT NULL
    , IdSemanaPlanilla INT NULL
    , FechaInicioSemana DATE NOT NULL
    , CONSTRAINT PK_JornadaEmpleadoSemana PRIMARY KEY CLUSTERED (Id)
    , CONSTRAINT UQ_JornadaEmpleadoSemana UNIQUE (IdEmpleado, IdSemanaPlanilla)
    , CONSTRAINT FK_JornadaEmpleadoSemana_Empleado FOREIGN KEY (IdEmpleado) REFERENCES dbo.Empleado (Id)
    , CONSTRAINT FK_JornadaEmpleadoSemana_TipoJornada FOREIGN KEY (IdTipoJornada) REFERENCES dbo.TipoJornada (Id)
    , CONSTRAINT FK_JornadaEmpleadoSemana_SemanaPlanilla FOREIGN KEY (IdSemanaPlanilla) REFERENCES dbo.SemanaPlanilla (Id)
);
GO

CREATE TABLE dbo.MarcaAsistencia
(
    Id INT IDENTITY(1, 1) NOT NULL
    , IdEmpleado INT NOT NULL
    , Fecha DATE NOT NULL
    , HoraEntrada DATETIME2(0) NOT NULL
    , HoraSalida DATETIME2(0) NOT NULL
    , Procesada BIT NOT NULL
        CONSTRAINT DF_MarcaAsistencia_Procesada DEFAULT (0)
    , CONSTRAINT PK_MarcaAsistencia PRIMARY KEY CLUSTERED (Id)
    , CONSTRAINT FK_MarcaAsistencia_Empleado FOREIGN KEY (IdEmpleado) REFERENCES dbo.Empleado (Id)
);
GO

/* ------------------------------------------------------------------ */
/* Movimientos                                                        */
/* ------------------------------------------------------------------ */

CREATE TABLE dbo.Movimiento
(
    Id INT IDENTITY(1, 1) NOT NULL
    , IdEmpleado INT NOT NULL
    , IdPlanillaSemanaEmpleado INT NOT NULL
    , IdTipoMovimiento INT NOT NULL
    , IdTipoDeduccion INT NULL
    , Fecha DATE NOT NULL
    , CantidadHoras INT NULL
    , Monto DECIMAL(14, 2) NOT NULL
    , NuevoSaldo DECIMAL(14, 2) NOT NULL
        CONSTRAINT DF_Movimiento_NuevoSaldo DEFAULT (0)
    , IdPostByUser INT NULL
    , PostInIP NVARCHAR(45) NULL
    , PostTime DATETIME2(0) NOT NULL
        CONSTRAINT DF_Movimiento_PostTime DEFAULT (SYSUTCDATETIME())
    , CONSTRAINT PK_Movimiento PRIMARY KEY CLUSTERED (Id)
    , CONSTRAINT FK_Movimiento_Empleado FOREIGN KEY (IdEmpleado) REFERENCES dbo.Empleado (Id)
    , CONSTRAINT FK_Movimiento_PlanillaSemanaEmpleado FOREIGN KEY (IdPlanillaSemanaEmpleado) REFERENCES dbo.PlanillaSemanaEmpleado (Id)
    , CONSTRAINT FK_Movimiento_TipoMovimiento FOREIGN KEY (IdTipoMovimiento) REFERENCES dbo.TipoMovimiento (Id)
    , CONSTRAINT FK_Movimiento_TipoDeduccion FOREIGN KEY (IdTipoDeduccion) REFERENCES dbo.TipoDeduccion (Id)
    , CONSTRAINT FK_Movimiento_Usuario FOREIGN KEY (IdPostByUser) REFERENCES dbo.Usuario (Id)
);
GO

/* ------------------------------------------------------------------ */
/* Trazabilidad                                                       */
/* ------------------------------------------------------------------ */

CREATE TABLE dbo.BitacoraEvento
(
    Id BIGINT IDENTITY(1, 1) NOT NULL
    , IdTipoEvento INT NOT NULL
    , IdUsuario INT NULL
    , IP NVARCHAR(45) NOT NULL
    , PostTime DATETIME2(0) NOT NULL
        CONSTRAINT DF_BitacoraEvento_PostTime DEFAULT (SYSUTCDATETIME())
    , Parametros NVARCHAR(MAX) NULL
    , ValoresAntes NVARCHAR(MAX) NULL
    , ValoresDespues NVARCHAR(MAX) NULL
    , CONSTRAINT PK_BitacoraEvento PRIMARY KEY CLUSTERED (Id)
    , CONSTRAINT FK_BitacoraEvento_TipoEvento FOREIGN KEY (IdTipoEvento) REFERENCES dbo.TipoEvento (Id)
    , CONSTRAINT FK_BitacoraEvento_Usuario FOREIGN KEY (IdUsuario) REFERENCES dbo.Usuario (Id)
    , CONSTRAINT CK_BitacoraEvento_Parametros CHECK (Parametros IS NULL OR ISJSON(Parametros) = 1)
    , CONSTRAINT CK_BitacoraEvento_ValoresAntes CHECK (ValoresAntes IS NULL OR ISJSON(ValoresAntes) = 1)
    , CONSTRAINT CK_BitacoraEvento_ValoresDespues CHECK (ValoresDespues IS NULL OR ISJSON(ValoresDespues) = 1)
);
GO

CREATE TABLE dbo.Error
(
    Id INT IDENTITY(1, 1) NOT NULL
    , Codigo INT NOT NULL
    , Descripcion NVARCHAR(1000) NOT NULL
    , CONSTRAINT PK_Error PRIMARY KEY CLUSTERED (Id)
    , CONSTRAINT UQ_Error_Codigo UNIQUE (Codigo)
);
GO

CREATE TABLE dbo.DBError
(
    Id INT IDENTITY(1, 1) NOT NULL
    , UserName NVARCHAR(200) NULL
    , Number INT NULL
    , State INT NULL
    , Severity INT NULL
    , Line INT NULL
    , [Procedure] NVARCHAR(200) NULL
    , [Message] NVARCHAR(MAX) NULL
    , [DateTime] DATETIME2(0) NOT NULL
        CONSTRAINT DF_DBError_DateTime DEFAULT (SYSDATETIME())
    , CONSTRAINT PK_DBError PRIMARY KEY CLUSTERED (Id)
);
GO

/* ------------------------------------------------------------------ */
/* Tipos de tabla (Table-Valued Parameters)                           */
/* ------------------------------------------------------------------ */

CREATE TYPE dbo.MarcaAsistenciaLista AS TABLE
(
    RowNum INT NOT NULL PRIMARY KEY
    , HoraEntrada DATETIME2(0) NOT NULL
    , HoraSalida DATETIME2(0) NOT NULL
);
GO

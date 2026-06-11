import {
  Injectable,
  InternalServerErrorException,
  Logger,
  OnModuleDestroy,
  OnModuleInit,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import * as sql from 'mssql';

export type LoginResult = {
  resultCode: number;
  idUsuario: number | null;
  idTipoUsuario: number | null;
  idEmpleado: number | null;
};

export type EmpleadoListRow = {
  ValorDocumentoIdentidad: string;
  NombreEmpleado: string;
  NombrePuesto: string;
};

export type PlanillaSemanalRow = {
  FechaInicioSemana: Date;
  FechaFinSemana: Date;
  SalarioBruto: number;
  TotalDeducciones: number;
  SalarioNeto: number;
  CantidadHorasOrdinarias: number;
  CantidadHorasExtraNormales: number;
  CantidadHorasExtraDobles: number;
};

export type DeduccionRow = {
  NombreDeduccion: string;
  PorcentajeAplicado: number | null;
  MontoDeduccion: number;
};

export type DetalleDiaRow = {
  Fecha: Date;
  HoraEntrada: Date;
  HoraSalida: Date;
  HorasOrdinarias: number;
  MontoOrdinario: number;
  HorasExtraNormales: number;
  MontoExtraNormal: number;
  HorasExtraDobles: number;
  MontoExtraDoble: number;
};

export type PlanillaMensualRow = {
  Anio: number;
  Mes: number;
  FechaInicio: Date;
  FechaFin: Date;
  SalarioBrutoMensual: number;
  TotalDeduccionesMensual: number;
  SalarioNetoMensual: number;
};

export type PuestoRow = {
  Id: number;
  Nombre: string;
  SalarioXHora: number;
};

export type CatalogoRow = {
  Id: number;
  Nombre: string;
};

export type SpListResult<T> = {
  resultCode: number;
  items: T[];
};

@Injectable()
export class DatabaseService implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(DatabaseService.name);
  private pool: sql.ConnectionPool | null = null;

  constructor(private readonly config: ConfigService) {}

  async onModuleInit(): Promise<void> {
    const host = this.config.get<string>('DB_HOST');
    const port = Number(this.config.get<string>('DB_PORT') ?? '1433');
    const database = this.config.get<string>('DB_NAME') ?? 'planilla_obrera';
    const user = this.config.get<string>('DB_USER');
    const password = this.config.get<string>('DB_PASSWORD');

    if (!host || !user || password === undefined || password === '') {
      this.logger.warn('Database env incomplete; SQL pool not started.');
      return;
    }

    const poolConfig: sql.config = {
      server: host,
      port,
      database,
      user,
      password,
      pool: { max: 10, min: 0, idleTimeoutMillis: 30000 },
      options: {
        encrypt: true,
        trustServerCertificate: true,
      },
    };

    this.pool = new sql.ConnectionPool(poolConfig);
    try {
      await this.pool.connect();
      this.logger.log('Pool de SQL Server conectado.');
    } catch (err) {
      this.logger.error('Falló la conexión a SQL Server', err instanceof Error ? err.stack : err);
      await this.pool.close().catch(() => undefined);
      this.pool = null;
    }
  }

  async onModuleDestroy(): Promise<void> {
    if (this.pool) {
      await this.pool.close();
      this.pool = null;
    }
  }

  getConnectionInfo() {
    return {
      host: this.config.get<string>('DB_HOST'),
      port: this.config.get<string>('DB_PORT'),
      database: this.config.get<string>('DB_NAME') ?? 'planilla_obrera',
      user: this.config.get<string>('DB_USER'),
    };
  }

  isReady(): boolean {
    return this.pool !== null && this.pool.connected;
  }

  private requirePool(): sql.ConnectionPool {
    if (!this.pool || !this.pool.connected) {
      throw new InternalServerErrorException({
        resultCode: 50008,
        message: 'Base de datos no disponible.',
      });
    }
    return this.pool;
  }

  async runAuthLogin(
    username: string,
    password: string,
    ip: string,
  ): Promise<LoginResult> {
    const request = this.requirePool().request();
    request.input('inUsername', sql.NVarChar(100), username);
    request.input('inPassword', sql.NVarChar(256), password);
    request.input('inIP', sql.NVarChar(45), ip);
    request.output('outIdUsuario', sql.Int);
    request.output('outIdTipoUsuario', sql.Int);
    request.output('outIdEmpleado', sql.Int);
    request.output('outResultCode', sql.Int);

    const executed = await request.execute('dbo.spAuth_Login');
    const out = executed.output as Record<string, unknown>;

    return {
      resultCode: Number(out.outResultCode ?? 50008),
      idUsuario: out.outIdUsuario != null ? Number(out.outIdUsuario) : null,
      idTipoUsuario:
        out.outIdTipoUsuario != null ? Number(out.outIdTipoUsuario) : null,
      idEmpleado: out.outIdEmpleado != null ? Number(out.outIdEmpleado) : null,
    };
  }

  async runAuthLogout(idUsuario: number, ip: string): Promise<number> {
    const request = this.requirePool().request();
    request.input('inIdUsuario', sql.Int, idUsuario);
    request.input('inIP', sql.NVarChar(45), ip);
    request.output('outResultCode', sql.Int);

    const executed = await request.execute('dbo.spAuth_Logout');
    const out = executed.output as Record<string, unknown>;

    return Number(out.outResultCode ?? 50008);
  }

  async getErrorDescription(codigo: number): Promise<string> {
    const request = this.requirePool().request();
    request.input('inCodigo', sql.Int, codigo);
    request.output('outDescripcion', sql.NVarChar(1000));
    request.output('outResultCode', sql.Int);

    const executed = await request.execute('dbo.spError_ObtenerPorCodigo');
    const out = executed.output as Record<string, unknown>;
    const descripcion = out.outDescripcion;

    if (typeof descripcion === 'string' && descripcion.trim() !== '') {
      return descripcion;
    }

    return 'Error de base de datos';
  }

  async runEmpleadoListar(
    idUsuario: number,
    ip: string,
  ): Promise<SpListResult<EmpleadoListRow>> {
    const request = this.requirePool().request();
    request.input('inIdUsuario', sql.Int, idUsuario);
    request.input('inIP', sql.NVarChar(45), ip);
    request.output('outResultCode', sql.Int);

    const executed = await request.execute('dbo.spEmpleado_Listar');
    const out = executed.output as Record<string, unknown>;
    const resultCode = Number(out.outResultCode ?? 50008);

    return {
      resultCode,
      items:
        resultCode === 0
          ? (executed.recordset as EmpleadoListRow[])
          : [],
    };
  }

  async runEmpleadoListarConFiltro(
    idUsuario: number,
    ip: string,
    filtro: string,
  ): Promise<SpListResult<EmpleadoListRow>> {
    const request = this.requirePool().request();
    request.input('inIdUsuario', sql.Int, idUsuario);
    request.input('inIP', sql.NVarChar(45), ip);
    request.input('inFiltro', sql.NVarChar(300), filtro);
    request.output('outResultCode', sql.Int);

    const executed = await request.execute('dbo.spEmpleado_ListarConFiltro');
    const out = executed.output as Record<string, unknown>;
    const resultCode = Number(out.outResultCode ?? 50008);

    return {
      resultCode,
      items:
        resultCode === 0
          ? (executed.recordset as EmpleadoListRow[])
          : [],
    };
  }

  async runEmpleadoInsertar(
    idUsuario: number,
    ip: string,
    nombre: string,
    valorDocumentoIdentidad: string,
    idTipoDocumento: number | null,
    idDepartamento: number | null,
    nombrePuesto: string,
    numeroCuentaBanco: string,
    fechaIngreso: Date | null,
    username: string | null,
    password: string | null,
  ): Promise<number> {
    const request = this.requirePool().request();
    request.input('inIdUsuario', sql.Int, idUsuario);
    request.input('inIP', sql.NVarChar(45), ip);
    request.input('inNombre', sql.NVarChar(300), nombre);
    request.input(
      'inValorDocumentoIdentidad',
      sql.NVarChar(50),
      valorDocumentoIdentidad,
    );
    request.input('inIdTipoDocumento', sql.Int, idTipoDocumento ?? null);
    request.input('inIdDepartamento', sql.Int, idDepartamento ?? null);
    request.input('inNombrePuesto', sql.NVarChar(200), nombrePuesto);
    request.input('inNumeroCuentaBanco', sql.NVarChar(50), numeroCuentaBanco);
    request.input('inFechaIngreso', sql.Date, fechaIngreso ?? null);
    request.input('inUsername', sql.NVarChar(100), username ?? null);
    request.input('inPassword', sql.NVarChar(256), password ?? null);
    request.output('outResultCode', sql.Int);

    const executed = await request.execute('dbo.spEmpleado_Insertar');
    const out = executed.output as Record<string, unknown>;

    return Number(out.outResultCode ?? 50008);
  }

  async runEmpleadoEditar(
    idUsuario: number,
    ip: string,
    valorDocumentoIdentidad: string,
    nuevoNombre: string | null,
    nuevoValorDocumentoIdentidad: string | null,
    nombrePuesto: string | null,
    idDepartamento: number | null,
    numeroCuentaBanco: string | null,
  ): Promise<number> {
    const request = this.requirePool().request();
    request.input('inIdUsuario', sql.Int, idUsuario);
    request.input('inIP', sql.NVarChar(45), ip);
    request.input(
      'inValorDocumentoIdentidad',
      sql.NVarChar(50),
      valorDocumentoIdentidad,
    );
    request.input('inNuevoNombre', sql.NVarChar(300), nuevoNombre ?? null);
    request.input(
      'inNuevoValorDocumentoIdentidad',
      sql.NVarChar(50),
      nuevoValorDocumentoIdentidad ?? null,
    );
    request.input('inNombrePuesto', sql.NVarChar(200), nombrePuesto ?? null);
    request.input('inIdDepartamento', sql.Int, idDepartamento ?? null);
    request.input(
      'inNumeroCuentaBanco',
      sql.NVarChar(50),
      numeroCuentaBanco ?? null,
    );
    request.output('outResultCode', sql.Int);

    const executed = await request.execute('dbo.spEmpleado_Editar');
    const out = executed.output as Record<string, unknown>;

    return Number(out.outResultCode ?? 50008);
  }

  async runEmpleadoEliminar(
    idUsuario: number,
    ip: string,
    valorDocumentoIdentidad: string,
    fechaSalida: Date | null,
  ): Promise<number> {
    const request = this.requirePool().request();
    request.input('inIdUsuario', sql.Int, idUsuario);
    request.input('inIP', sql.NVarChar(45), ip);
    request.input(
      'inValorDocumentoIdentidad',
      sql.NVarChar(50),
      valorDocumentoIdentidad,
    );
    request.input('inFechaSalida', sql.Date, fechaSalida ?? null);
    request.output('outResultCode', sql.Int);

    const executed = await request.execute('dbo.spEmpleado_Eliminar');
    const out = executed.output as Record<string, unknown>;

    return Number(out.outResultCode ?? 50008);
  }

  async runEmpleadoImpersonar(
    idUsuarioAdmin: number,
    ip: string,
    valorDocumentoIdentidad: string,
  ): Promise<{ resultCode: number; item: EmpleadoListRow | null }> {
    const request = this.requirePool().request();
    request.input('inIdUsuarioAdmin', sql.Int, idUsuarioAdmin);
    request.input('inIP', sql.NVarChar(45), ip);
    request.input(
      'inValorDocumentoIdentidad',
      sql.NVarChar(50),
      valorDocumentoIdentidad,
    );
    request.output('outResultCode', sql.Int);

    const executed = await request.execute('dbo.spEmpleado_Impersonar');
    const out = executed.output as Record<string, unknown>;
    const resultCode = Number(out.outResultCode ?? 50008);
    const rows = executed.recordset as EmpleadoListRow[];

    return {
      resultCode,
      item: resultCode === 0 && rows.length > 0 ? rows[0] : null,
    };
  }

  async runEmpleadoRegresarAdmin(idUsuario: number, ip: string): Promise<number> {
    const request = this.requirePool().request();
    request.input('inIdUsuario', sql.Int, idUsuario);
    request.input('inIP', sql.NVarChar(45), ip);
    request.output('outResultCode', sql.Int);

    const executed = await request.execute('dbo.spEmpleado_RegresarAdmin');
    const out = executed.output as Record<string, unknown>;

    return Number(out.outResultCode ?? 50008);
  }

  async runPlanillaConsultarSemanal(
    idUsuario: number,
    ip: string,
    valorDocumentoIdentidad: string,
    cantidadSemanas: number | null,
  ): Promise<SpListResult<PlanillaSemanalRow>> {
    const request = this.requirePool().request();
    request.input('inIdUsuario', sql.Int, idUsuario);
    request.input('inIP', sql.NVarChar(45), ip);
    request.input(
      'inValorDocumentoIdentidad',
      sql.NVarChar(50),
      valorDocumentoIdentidad,
    );
    request.input('inCantidadSemanas', sql.Int, cantidadSemanas ?? null);
    request.output('outResultCode', sql.Int);

    const executed = await request.execute('dbo.spPlanilla_ConsultarSemanal');
    const out = executed.output as Record<string, unknown>;
    const resultCode = Number(out.outResultCode ?? 50008);

    return {
      resultCode,
      items:
        resultCode === 0
          ? (executed.recordset as PlanillaSemanalRow[])
          : [],
    };
  }

  async runPlanillaConsultarDeduccionesSemana(
    idUsuario: number,
    ip: string,
    valorDocumentoIdentidad: string,
    fechaInicioSemana: Date,
  ): Promise<SpListResult<DeduccionRow>> {
    const request = this.requirePool().request();
    request.input('inIdUsuario', sql.Int, idUsuario);
    request.input('inIP', sql.NVarChar(45), ip);
    request.input(
      'inValorDocumentoIdentidad',
      sql.NVarChar(50),
      valorDocumentoIdentidad,
    );
    request.input('inFechaInicioSemana', sql.Date, fechaInicioSemana);
    request.output('outResultCode', sql.Int);

    const executed = await request.execute(
      'dbo.spPlanilla_ConsultarDeduccionesSemana',
    );
    const out = executed.output as Record<string, unknown>;
    const resultCode = Number(out.outResultCode ?? 50008);

    return {
      resultCode,
      items:
        resultCode === 0 ? (executed.recordset as DeduccionRow[]) : [],
    };
  }

  async runPlanillaConsultarDetalleSemana(
    idUsuario: number,
    ip: string,
    valorDocumentoIdentidad: string,
    fechaInicioSemana: Date,
  ): Promise<SpListResult<DetalleDiaRow>> {
    const request = this.requirePool().request();
    request.input('inIdUsuario', sql.Int, idUsuario);
    request.input('inIP', sql.NVarChar(45), ip);
    request.input(
      'inValorDocumentoIdentidad',
      sql.NVarChar(50),
      valorDocumentoIdentidad,
    );
    request.input('inFechaInicioSemana', sql.Date, fechaInicioSemana);
    request.output('outResultCode', sql.Int);

    const executed = await request.execute(
      'dbo.spPlanilla_ConsultarDetalleSemana',
    );
    const out = executed.output as Record<string, unknown>;
    const resultCode = Number(out.outResultCode ?? 50008);

    return {
      resultCode,
      items:
        resultCode === 0 ? (executed.recordset as DetalleDiaRow[]) : [],
    };
  }

  async runPlanillaConsultarMensual(
    idUsuario: number,
    ip: string,
    valorDocumentoIdentidad: string,
    cantidadMeses: number | null,
  ): Promise<SpListResult<PlanillaMensualRow>> {
    const request = this.requirePool().request();
    request.input('inIdUsuario', sql.Int, idUsuario);
    request.input('inIP', sql.NVarChar(45), ip);
    request.input(
      'inValorDocumentoIdentidad',
      sql.NVarChar(50),
      valorDocumentoIdentidad,
    );
    request.input('inCantidadMeses', sql.Int, cantidadMeses ?? null);
    request.output('outResultCode', sql.Int);

    const executed = await request.execute('dbo.spPlanilla_ConsultarMensual');
    const out = executed.output as Record<string, unknown>;
    const resultCode = Number(out.outResultCode ?? 50008);

    return {
      resultCode,
      items:
        resultCode === 0
          ? (executed.recordset as PlanillaMensualRow[])
          : [],
    };
  }

  async runPlanillaConsultarDeduccionesMes(
    idUsuario: number,
    ip: string,
    valorDocumentoIdentidad: string,
    anio: number,
    mes: number,
  ): Promise<SpListResult<DeduccionRow>> {
    const request = this.requirePool().request();
    request.input('inIdUsuario', sql.Int, idUsuario);
    request.input('inIP', sql.NVarChar(45), ip);
    request.input(
      'inValorDocumentoIdentidad',
      sql.NVarChar(50),
      valorDocumentoIdentidad,
    );
    request.input('inAnio', sql.Int, anio);
    request.input('inMes', sql.Int, mes);
    request.output('outResultCode', sql.Int);

    const executed = await request.execute(
      'dbo.spPlanilla_ConsultarDeduccionesMes',
    );
    const out = executed.output as Record<string, unknown>;
    const resultCode = Number(out.outResultCode ?? 50008);

    return {
      resultCode,
      items:
        resultCode === 0 ? (executed.recordset as DeduccionRow[]) : [],
    };
  }

  async runCatalogoListarPuestos(): Promise<SpListResult<PuestoRow>> {
    const request = this.requirePool().request();
    request.output('outResultCode', sql.Int);

    const executed = await request.execute('dbo.spCatalogo_ListarPuestos');
    const out = executed.output as Record<string, unknown>;
    const resultCode = Number(out.outResultCode ?? 50008);

    return {
      resultCode,
      items: resultCode === 0 ? (executed.recordset as PuestoRow[]) : [],
    };
  }

  async runCatalogoListarDepartamentos(): Promise<SpListResult<CatalogoRow>> {
    const request = this.requirePool().request();
    request.output('outResultCode', sql.Int);

    const executed = await request.execute('dbo.spCatalogo_ListarDepartamentos');
    const out = executed.output as Record<string, unknown>;
    const resultCode = Number(out.outResultCode ?? 50008);

    return {
      resultCode,
      items: resultCode === 0 ? (executed.recordset as CatalogoRow[]) : [],
    };
  }

  async runCatalogoListarTiposDocumento(): Promise<SpListResult<CatalogoRow>> {
    const request = this.requirePool().request();
    request.output('outResultCode', sql.Int);

    const executed = await request.execute('dbo.spCatalogo_ListarTiposDocumento');
    const out = executed.output as Record<string, unknown>;
    const resultCode = Number(out.outResultCode ?? 50008);

    return {
      resultCode,
      items: resultCode === 0 ? (executed.recordset as CatalogoRow[]) : [],
    };
  }
}

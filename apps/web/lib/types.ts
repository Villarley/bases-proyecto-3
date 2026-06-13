export type TipoUsuario = 'administrador' | 'empleado';

export type LoginResponse = {
  idUsuario: number;
  idTipoUsuario: number;
  tipoUsuario: TipoUsuario;
  idEmpleado: number | null;
};

export type EmpleadoListRow = {
  ValorDocumentoIdentidad: string;
  NombreEmpleado: string;
  NombrePuesto: string;
};

export type PlanillaSemanalRow = {
  FechaInicioSemana: string;
  FechaFinSemana: string;
  SalarioBruto: number;
  TotalDeducciones: number;
  SalarioNeto: number;
  CantidadHorasOrdinarias: number;
  CantidadHorasExtraNormales: number;
  CantidadHorasExtraDobles: number;
};

export type PlanillaMensualRow = {
  Anio: number;
  Mes: number;
  FechaInicio: string;
  FechaFin: string;
  SalarioBrutoMensual: number;
  TotalDeduccionesMensual: number;
  SalarioNetoMensual: number;
};

export type DeduccionRow = {
  NombreDeduccion: string;
  PorcentajeAplicado: number | null;
  MontoDeduccion: number;
};

export type DetalleDiaRow = {
  Fecha: string;
  HoraEntrada: string;
  HoraSalida: string;
  HorasOrdinarias: number;
  MontoOrdinario: number;
  HorasExtraNormales: number;
  MontoExtraNormal: number;
  HorasExtraDobles: number;
  MontoExtraDoble: number;
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

export type ListResponse<T> = { items: T[] };

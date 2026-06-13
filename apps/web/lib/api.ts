import type {
  CatalogoRow,
  DeduccionRow,
  DetalleDiaRow,
  EmpleadoListRow,
  ListResponse,
  LoginResponse,
  PlanillaMensualRow,
  PlanillaSemanalRow,
  PuestoRow,
} from './types';

const BASE = process.env.NEXT_PUBLIC_API_URL ?? 'http://localhost:4000';

export class ApiError extends Error {
  status: number;
  resultCode?: number;
  constructor(status: number, message: string, resultCode?: number) {
    super(message);
    this.status = status;
    this.resultCode = resultCode;
  }
}

async function apiFetch<T>(path: string, init?: RequestInit): Promise<T> {
  const headers: Record<string, string> = {
    'Content-Type': 'application/json',
    ...(init?.headers as Record<string, string>),
  };

  const res = await fetch(`${BASE}${path}`, { ...init, headers });

  if (res.status === 204) return undefined as T;

  const body = (await res.json().catch(() => ({}))) as Record<string, unknown>;

  if (!res.ok) {
    const message =
      (typeof body.message === 'string' && body.message) ||
      (Array.isArray(body.message) && body.message.join(', ')) ||
      'Ocurrió un error al comunicarse con el servidor.';
    throw new ApiError(
      res.status,
      message,
      typeof body.resultCode === 'number' ? body.resultCode : undefined,
    );
  }

  return body as T;
}

function qs(params: Record<string, string | number | undefined | null>): string {
  const sp = new URLSearchParams();
  for (const [k, v] of Object.entries(params)) {
    if (v !== undefined && v !== null && v !== '') sp.set(k, String(v));
  }
  const s = sp.toString();
  return s ? `?${s}` : '';
}

// ---- Auth ----
export const login = (username: string, password: string) =>
  apiFetch<LoginResponse>('/auth/login', {
    method: 'POST',
    body: JSON.stringify({ username, password }),
  });

export const logout = (idUsuario: number) =>
  apiFetch<unknown>('/auth/logout', {
    method: 'POST',
    body: JSON.stringify({ idUsuario }),
  });

// ---- Empleados ----
export const listEmpleados = (idUsuario: number, filtro?: string) =>
  apiFetch<ListResponse<EmpleadoListRow>>(
    `/empleados${qs({ idUsuario, filtro })}`,
  );

export type CreateEmpleadoPayload = {
  idUsuario: number;
  nombre: string;
  valorDocumentoIdentidad: string;
  nombrePuesto: string;
  numeroCuentaBanco?: string;
  idTipoDocumento?: number;
  idDepartamento?: number;
  fechaIngreso?: string;
  username?: string;
  password?: string;
};

export const createEmpleado = (payload: CreateEmpleadoPayload) =>
  apiFetch<{ resultCode: number }>('/empleados', {
    method: 'POST',
    body: JSON.stringify(payload),
  });

export type UpdateEmpleadoPayload = {
  idUsuario: number;
  nuevoNombre?: string;
  nuevoValorDocumentoIdentidad?: string;
  nombrePuesto?: string;
  idDepartamento?: number;
  numeroCuentaBanco?: string;
};

export const editEmpleado = (
  documento: string,
  payload: UpdateEmpleadoPayload,
) =>
  apiFetch<{ resultCode: number }>(`/empleados/${encodeURIComponent(documento)}`, {
    method: 'PUT',
    body: JSON.stringify(payload),
  });

export const deleteEmpleado = (
  documento: string,
  idUsuario: number,
  fechaSalida?: string,
) =>
  apiFetch<{ resultCode: number }>(`/empleados/${encodeURIComponent(documento)}`, {
    method: 'DELETE',
    body: JSON.stringify({ idUsuario, fechaSalida }),
  });

export const impersonar = (documento: string, idUsuarioAdmin: number) =>
  apiFetch<EmpleadoListRow>(
    `/empleados/${encodeURIComponent(documento)}/impersonar`,
    { method: 'POST', body: JSON.stringify({ idUsuarioAdmin }) },
  );

export const regresarAdmin = (idUsuario: number) =>
  apiFetch<{ resultCode: number }>('/empleados/regresar-admin', {
    method: 'POST',
    body: JSON.stringify({ idUsuario }),
  });

// ---- Catálogos ----
export const listPuestos = () =>
  apiFetch<ListResponse<PuestoRow>>('/catalogos/puestos');
export const listDepartamentos = () =>
  apiFetch<ListResponse<CatalogoRow>>('/catalogos/departamentos');
export const listTiposDocumento = () =>
  apiFetch<ListResponse<CatalogoRow>>('/catalogos/tipos-documento');

// ---- Planilla ----
export const planillaSemanal = (
  idUsuario: number,
  documento: string,
  cantidadSemanas?: number,
) =>
  apiFetch<ListResponse<PlanillaSemanalRow>>(
    `/planilla/semanal${qs({ idUsuario, documento, cantidadSemanas })}`,
  );

export const deduccionesSemana = (
  idUsuario: number,
  documento: string,
  fechaInicioSemana: string,
) =>
  apiFetch<ListResponse<DeduccionRow>>(
    `/planilla/semanal/deducciones${qs({ idUsuario, documento, fechaInicioSemana })}`,
  );

export const detalleSemana = (
  idUsuario: number,
  documento: string,
  fechaInicioSemana: string,
) =>
  apiFetch<ListResponse<DetalleDiaRow>>(
    `/planilla/semanal/detalle${qs({ idUsuario, documento, fechaInicioSemana })}`,
  );

export const planillaMensual = (
  idUsuario: number,
  documento: string,
  cantidadMeses?: number,
) =>
  apiFetch<ListResponse<PlanillaMensualRow>>(
    `/planilla/mensual${qs({ idUsuario, documento, cantidadMeses })}`,
  );

export const deduccionesMes = (
  idUsuario: number,
  documento: string,
  anio: number,
  mes: number,
) =>
  apiFetch<ListResponse<DeduccionRow>>(
    `/planilla/mensual/deducciones${qs({ idUsuario, documento, anio, mes })}`,
  );

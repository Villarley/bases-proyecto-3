/** Tipos de dominio compartidos — extender según crezca la app. */

export type TipoUsuario = 'administrador' | 'empleado';

export interface EmpleadoListItem {
  nombre: string;
  puesto: string;
}

export interface ApiResult<T> {
  resultCode: number;
  data: T | null;
}

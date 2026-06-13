import type { TipoUsuario } from './types';

const KEY = 'planilla.session';

export type Session = {
  idUsuario: number;
  idTipoUsuario: number;
  tipoUsuario: TipoUsuario;
  idEmpleado: number | null;
  empleadoDocumento?: string;
  empleadoNombre?: string;
  impersonando: boolean;
};

export function getSession(): Session | null {
  if (typeof window === 'undefined') return null;
  const raw = window.localStorage.getItem(KEY);
  if (!raw) return null;
  try {
    return JSON.parse(raw) as Session;
  } catch {
    return null;
  }
}

export function setSession(session: Session): void {
  if (typeof window === 'undefined') return;
  window.localStorage.setItem(KEY, JSON.stringify(session));
}

export function clearSession(): void {
  if (typeof window === 'undefined') return;
  window.localStorage.removeItem(KEY);
}

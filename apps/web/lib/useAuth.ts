'use client';

import { useRouter } from 'next/navigation';
import { useEffect, useState } from 'react';
import { getSession, type Session } from './session';
import type { TipoUsuario } from './types';

export function useAuth(requiredRole?: TipoUsuario) {
  const router = useRouter();
  const [session, setSessionState] = useState<Session | null>(null);

  useEffect(() => {
    const s = getSession();
    if (!s) {
      router.replace('/login');
      return;
    }
    if (requiredRole && s.tipoUsuario !== requiredRole && !s.impersonando) {
      router.replace(s.tipoUsuario === 'administrador' ? '/admin' : '/empleado');
      return;
    }
    setSessionState(s);
  }, [router, requiredRole]);

  return session;
}

'use client';

import { useRouter } from 'next/navigation';
import { Button } from './ui';
import { logout } from '../lib/api';
import { clearSession, getSession } from '../lib/session';

export function TopBar({ subtitle }: { subtitle: string }) {
  const router = useRouter();

  async function onLogout() {
    const s = getSession();
    if (s) await logout(s.idUsuario).catch(() => undefined);
    clearSession();
    router.replace('/login');
  }

  return (
    <header className="flex items-center justify-between border-b border-zinc-200 px-6 py-3">
      <div>
        <h1 className="text-lg font-semibold tracking-tight">Planilla Obrera</h1>
        <p className="text-xs text-zinc-500">{subtitle}</p>
      </div>
      <Button variant="outline" onClick={onLogout}>
        Cerrar sesión
      </Button>
    </header>
  );
}

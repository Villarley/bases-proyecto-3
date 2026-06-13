'use client';

import { useRouter } from 'next/navigation';
import { useEffect } from 'react';
import { getSession } from '../lib/session';

export default function HomePage() {
  const router = useRouter();

  useEffect(() => {
    const s = getSession();
    if (!s) router.replace('/login');
    else router.replace(s.tipoUsuario === 'administrador' ? '/admin' : '/empleado');
  }, [router]);

  return (
    <main className="mx-auto flex min-h-screen max-w-2xl items-center justify-center p-6">
      <p className="text-sm text-zinc-500">Redirigiendo…</p>
    </main>
  );
}

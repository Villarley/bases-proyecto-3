'use client';

import { useRouter } from 'next/navigation';
import { useState } from 'react';
import { Alert, Button, Field, Input } from '../../components/ui';
import { login as apiLogin } from '../../lib/api';
import { setSession } from '../../lib/session';

export default function LoginPage() {
  const router = useRouter();
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);

  async function onSubmit(e: React.FormEvent) {
    e.preventDefault();
    setError('');
    setLoading(true);
    try {
      const res = await apiLogin(username.trim(), password);
      setSession({
        idUsuario: res.idUsuario,
        idTipoUsuario: res.idTipoUsuario,
        tipoUsuario: res.tipoUsuario,
        idEmpleado: res.idEmpleado,
        impersonando: false,
      });
      router.push(res.tipoUsuario === 'administrador' ? '/admin' : '/empleado');
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Credenciales inválidas.');
    } finally {
      setLoading(false);
    }
  }

  return (
    <main className="mx-auto flex min-h-screen max-w-sm flex-col justify-center gap-6 p-6">
      <div>
        <h1 className="text-2xl font-semibold tracking-tight">Iniciar Sesión</h1>
      </div>
      <form onSubmit={onSubmit} className="flex flex-col gap-4">
        <Field label="Usuario">
          <Input
            value={username}
            onChange={(e) => setUsername(e.target.value)}
            autoComplete="username"
            required
          />
        </Field>
        <Field label="Contraseña">
          <Input
            type="password"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            autoComplete="current-password"
            required
          />
        </Field>
        <Alert message={error} />
        <Button type="submit" disabled={loading}>
          {loading ? 'Ingresando…' : 'Ingresar'}
        </Button>
      </form>
    </main>
  );
}

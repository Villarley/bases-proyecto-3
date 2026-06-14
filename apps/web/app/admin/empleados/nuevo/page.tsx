'use client';

import { useRouter } from 'next/navigation';
import { useEffect, useState } from 'react';
import { TopBar } from '../../../../components/TopBar';
import { Alert, Button, Field, Input, Select } from '../../../../components/ui';
import {
  createEmpleado,
  listDepartamentos,
  listPuestos,
  listTiposDocumento,
} from '../../../../lib/api';
import { getSession } from '../../../../lib/session';
import type { CatalogoRow, PuestoRow } from '../../../../lib/types';
import { useAuth } from '../../../../lib/useAuth';

export default function NuevoEmpleadoPage() {
  const session = useAuth('administrador');
  const router = useRouter();

  const [puestos, setPuestos] = useState<PuestoRow[]>([]);
  const [departamentos, setDepartamentos] = useState<CatalogoRow[]>([]);
  const [tiposDoc, setTiposDoc] = useState<CatalogoRow[]>([]);

  const [nombre, setNombre] = useState('');
  const [documento, setDocumento] = useState('');
  const [nombrePuesto, setNombrePuesto] = useState('');
  const [idTipoDocumento, setIdTipoDocumento] = useState('');
  const [idDepartamento, setIdDepartamento] = useState('');
  const [cuenta, setCuenta] = useState('');
  const [fechaIngreso, setFechaIngreso] = useState('');
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');

  const [error, setError] = useState('');
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    if (!session) return;
    void (async () => {
      const [p, d, t] = await Promise.all([
        listPuestos().catch(() => ({ items: [] })),
        listDepartamentos().catch(() => ({ items: [] })),
        listTiposDocumento().catch(() => ({ items: [] })),
      ]);
      setPuestos(p.items);
      setDepartamentos(d.items);
      setTiposDoc(t.items);
    })();
  }, [session]);

  async function onSubmit(e: React.FormEvent) {
    e.preventDefault();
    const s = getSession();
    if (!s) return;
    setBusy(true);
    setError('');
    try {
      await createEmpleado({
        idUsuario: s.idUsuario,
        nombre: nombre.trim(),
        valorDocumentoIdentidad: documento.trim(),
        nombrePuesto,
        numeroCuentaBanco: cuenta.trim() || undefined,
        idTipoDocumento: idTipoDocumento ? Number(idTipoDocumento) : undefined,
        idDepartamento: idDepartamento ? Number(idDepartamento) : undefined,
        fechaIngreso: fechaIngreso || undefined,
        username: username.trim() || undefined,
        password: password || undefined,
      });
      router.push('/admin');
    } catch (err) {
      setError(err instanceof Error ? err.message : 'No se pudo crear el empleado.');
    } finally {
      setBusy(false);
    }
  }

  if (!session) return null;

  return (
    <div className="min-h-screen">
      <TopBar subtitle="Administrador" />
      <main className="mx-auto max-w-2xl p-6">
        <h2 className="mb-4 text-xl font-semibold">Agregar empleado</h2>
        <form onSubmit={onSubmit} className="grid grid-cols-1 gap-4 sm:grid-cols-2">
          <Field label="Nombre">
            <Input value={nombre} onChange={(e) => setNombre(e.target.value)} required />
          </Field>
          <Field label="Documento de identidad">
            <Input
              value={documento}
              onChange={(e) => setDocumento(e.target.value)}
              required
            />
          </Field>
          <Field label="Puesto">
            <Select
              value={nombrePuesto}
              onChange={(e) => setNombrePuesto(e.target.value)}
              required
            >
              <option value="">Seleccione…</option>
              {puestos.map((p) => (
                <option key={p.Id} value={p.Nombre}>
                  {p.Nombre}
                </option>
              ))}
            </Select>
          </Field>
          <Field label="Tipo de documento">
            <Select
              value={idTipoDocumento}
              onChange={(e) => setIdTipoDocumento(e.target.value)}
            >
              <option value="">(Opcional)</option>
              {tiposDoc.map((t) => (
                <option key={t.Id} value={t.Id}>
                  {t.Nombre}
                </option>
              ))}
            </Select>
          </Field>
          <Field label="Departamento">
            <Select
              value={idDepartamento}
              onChange={(e) => setIdDepartamento(e.target.value)}
            >
              <option value="">(Opcional)</option>
              {departamentos.map((d) => (
                <option key={d.Id} value={d.Id}>
                  {d.Nombre}
                </option>
              ))}
            </Select>
          </Field>
          <Field label="Número de cuenta bancaria">
            <Input value={cuenta} onChange={(e) => setCuenta(e.target.value)} />
          </Field>
          <Field label="Fecha de ingreso">
            <Input
              type="date"
              value={fechaIngreso}
              onChange={(e) => setFechaIngreso(e.target.value)}
            />
          </Field>
          <Field label="Usuario (login)">
            <Input value={username} onChange={(e) => setUsername(e.target.value)} />
          </Field>
          <Field label="Contraseña">
            <Input
              type="password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
            />
          </Field>

          <div className="sm:col-span-2">
            <Alert message={error} />
          </div>
          <div className="flex gap-2 sm:col-span-2">
            <Button type="submit" disabled={busy}>
              {busy ? 'Guardando…' : 'Guardar'}
            </Button>
            <Button type="button" variant="outline" onClick={() => router.push('/admin')}>
              Cancelar
            </Button>
          </div>
        </form>
      </main>
    </div>
  );
}

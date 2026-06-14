'use client';

import { useParams, useRouter, useSearchParams } from 'next/navigation';
import { Suspense, useEffect, useState } from 'react';
import { TopBar } from '../../../../components/TopBar';
import { Alert, Button, Field, Input, Select } from '../../../../components/ui';
import { editEmpleado, listDepartamentos, listPuestos } from '../../../../lib/api';
import { getSession } from '../../../../lib/session';
import type { CatalogoRow, PuestoRow } from '../../../../lib/types';
import { useAuth } from '../../../../lib/useAuth';

function EditarEmpleadoInner() {
  const session = useAuth('administrador');
  const router = useRouter();
  const params = useParams<{ documento: string }>();
  const search = useSearchParams();
  const documento = decodeURIComponent(params.documento);

  const [puestos, setPuestos] = useState<PuestoRow[]>([]);
  const [departamentos, setDepartamentos] = useState<CatalogoRow[]>([]);

  const [nombre, setNombre] = useState(search.get('nombre') ?? '');
  const [nuevoDocumento, setNuevoDocumento] = useState(documento);
  const [nombrePuesto, setNombrePuesto] = useState(search.get('puesto') ?? '');
  const [idDepartamento, setIdDepartamento] = useState('');
  const [cuenta, setCuenta] = useState('');

  const [error, setError] = useState('');
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    if (!session) return;
    void (async () => {
      const [p, d] = await Promise.all([
        listPuestos().catch(() => ({ items: [] })),
        listDepartamentos().catch(() => ({ items: [] })),
      ]);
      setPuestos(p.items);
      setDepartamentos(d.items);
    })();
  }, [session]);

  async function onSubmit(e: React.FormEvent) {
    e.preventDefault();
    const s = getSession();
    if (!s) return;
    setBusy(true);
    setError('');
    try {
      await editEmpleado(documento, {
        idUsuario: s.idUsuario,
        nuevoNombre: nombre.trim() || undefined,
        nuevoValorDocumentoIdentidad:
          nuevoDocumento.trim() !== documento ? nuevoDocumento.trim() : undefined,
        nombrePuesto: nombrePuesto || undefined,
        idDepartamento: idDepartamento ? Number(idDepartamento) : undefined,
        numeroCuentaBanco: cuenta.trim() || undefined,
      });
      router.push('/admin');
    } catch (err) {
      setError(err instanceof Error ? err.message : 'No se pudo editar el empleado.');
    } finally {
      setBusy(false);
    }
  }

  if (!session) return null;

  return (
    <div className="min-h-screen">
      <TopBar subtitle="Administrador" />
      <main className="mx-auto max-w-2xl p-6">
        <h2 className="mb-1 text-xl font-semibold">Editar empleado</h2>
        <p className="mb-4 text-sm text-zinc-500">Documento actual: {documento}</p>
        <form onSubmit={onSubmit} className="grid grid-cols-1 gap-4 sm:grid-cols-2">
          <Field label="Nombre">
            <Input value={nombre} onChange={(e) => setNombre(e.target.value)} />
          </Field>
          <Field label="Documento de identidad">
            <Input
              value={nuevoDocumento}
              onChange={(e) => setNuevoDocumento(e.target.value)}
            />
          </Field>
          <Field label="Puesto">
            <Select
              value={nombrePuesto}
              onChange={(e) => setNombrePuesto(e.target.value)}
            >
              <option value="">(Sin cambio)</option>
              {puestos.map((p) => (
                <option key={p.Id} value={p.Nombre}>
                  {p.Nombre}
                </option>
              ))}
            </Select>
          </Field>
          <Field label="Departamento">
            <Select
              value={idDepartamento}
              onChange={(e) => setIdDepartamento(e.target.value)}
            >
              <option value="">(Sin cambio)</option>
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

          <div className="sm:col-span-2">
            <Alert message={error} />
          </div>
          <div className="flex gap-2 sm:col-span-2">
            <Button type="submit" disabled={busy}>
              {busy ? 'Guardando…' : 'Guardar cambios'}
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

export default function EditarEmpleadoPage() {
  return (
    <Suspense fallback={null}>
      <EditarEmpleadoInner />
    </Suspense>
  );
}

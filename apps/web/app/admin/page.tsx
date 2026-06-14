'use client';

import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { useCallback, useEffect, useState } from 'react';
import { TopBar } from '../../components/TopBar';
import { Alert, Button, Input, Modal, Spinner } from '../../components/ui';
import {
  deleteEmpleado,
  impersonar,
  listEmpleados,
} from '../../lib/api';
import { getSession, setSession } from '../../lib/session';
import type { EmpleadoListRow } from '../../lib/types';
import { useAuth } from '../../lib/useAuth';

export default function AdminPage() {
  const session = useAuth('administrador');
  const router = useRouter();
  const [filtro, setFiltro] = useState('');
  const [items, setItems] = useState<EmpleadoListRow[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [toDelete, setToDelete] = useState<EmpleadoListRow | null>(null);
  const [busy, setBusy] = useState(false);

  const cargar = useCallback(
    async (texto?: string) => {
      const s = getSession();
      if (!s) return;
      setLoading(true);
      setError('');
      try {
        const res = await listEmpleados(s.idUsuario, texto?.trim() || undefined);
        setItems(res.items);
      } catch (err) {
        setError(err instanceof Error ? err.message : 'Error al listar empleados.');
      } finally {
        setLoading(false);
      }
    },
    [],
  );

  useEffect(() => {
    if (session) void cargar();
  }, [session, cargar]);

  async function onImpersonar(emp: EmpleadoListRow) {
    const s = getSession();
    if (!s) return;
    setBusy(true);
    setError('');
    try {
      const item = await impersonar(emp.ValorDocumentoIdentidad, s.idUsuario);
      setSession({
        ...s,
        empleadoDocumento: item.ValorDocumentoIdentidad,
        empleadoNombre: item.NombreEmpleado,
        impersonando: true,
      });
      router.push('/empleado');
    } catch (err) {
      setError(err instanceof Error ? err.message : 'No se pudo impersonar.');
    } finally {
      setBusy(false);
    }
  }

  async function onDelete() {
    const s = getSession();
    if (!s || !toDelete) return;
    setBusy(true);
    setError('');
    try {
      await deleteEmpleado(toDelete.ValorDocumentoIdentidad, s.idUsuario);
      setToDelete(null);
      await cargar(filtro);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'No se pudo eliminar.');
    } finally {
      setBusy(false);
    }
  }

  if (!session) return null;

  return (
    <div className="min-h-screen">
      <TopBar subtitle="Administrador" />
      <main className="mx-auto max-w-5xl p-6">
        <div className="mb-4 flex flex-wrap items-end justify-between gap-3">
          <h2 className="text-xl font-semibold">Empleados</h2>
          <Link href="/admin/empleados/nuevo">
            <Button>+ Agregar empleado</Button>
          </Link>
        </div>

        <form
          className="mb-4 flex gap-2"
          onSubmit={(e) => {
            e.preventDefault();
            void cargar(filtro);
          }}
        >
          <Input
            placeholder="Filtrar por nombre…"
            value={filtro}
            onChange={(e) => setFiltro(e.target.value)}
            className="flex-1"
          />
          <Button type="submit" variant="outline">
            Buscar
          </Button>
          <Button
            type="button"
            variant="ghost"
            onClick={() => {
              setFiltro('');
              void cargar();
            }}
          >
            Limpiar
          </Button>
        </form>

        <Alert message={error} />

        {loading ? (
          <Spinner />
        ) : (
          <div className="overflow-x-auto rounded-lg border border-zinc-200">
            <table className="w-full text-sm">
              <thead className="border-b border-zinc-200 bg-zinc-100 text-left">
                <tr>
                  <th className="px-4 py-2 font-medium">Nombre</th>
                  <th className="px-4 py-2 font-medium">Puesto</th>
                  <th className="px-4 py-2 font-medium">Documento</th>
                  <th className="px-4 py-2 text-right font-medium">Acciones</th>
                </tr>
              </thead>
              <tbody>
                {items.length === 0 && (
                  <tr>
                    <td colSpan={4} className="px-4 py-6 text-center text-zinc-500">
                      Sin empleados.
                    </td>
                  </tr>
                )}
                {items.map((emp) => (
                  <tr
                    key={emp.ValorDocumentoIdentidad}
                    className="border-b border-zinc-100 last:border-0"
                  >
                    <td className="px-4 py-2">{emp.NombreEmpleado}</td>
                    <td className="px-4 py-2 text-zinc-600">{emp.NombrePuesto}</td>
                    <td className="px-4 py-2 text-zinc-600">
                      {emp.ValorDocumentoIdentidad}
                    </td>
                    <td className="px-4 py-2">
                      <div className="flex justify-end gap-2">
                        <Link
                          href={{
                            pathname: `/admin/empleados/${encodeURIComponent(
                              emp.ValorDocumentoIdentidad,
                            )}`,
                            query: {
                              nombre: emp.NombreEmpleado,
                              puesto: emp.NombrePuesto,
                            },
                          }}
                        >
                          <Button variant="outline">Editar</Button>
                        </Link>
                        <Button
                          variant="outline"
                          disabled={busy}
                          onClick={() => onImpersonar(emp)}
                        >
                          Impersonar
                        </Button>
                        <Button
                          variant="ghost"
                          disabled={busy}
                          onClick={() => setToDelete(emp)}
                        >
                          Eliminar
                        </Button>
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </main>

      {toDelete && (
        <Modal title="Eliminar empleado" onClose={() => setToDelete(null)}>
          <p className="mb-4 text-sm">
            ¿Eliminar a <strong>{toDelete.NombreEmpleado}</strong> (
            {toDelete.ValorDocumentoIdentidad})? Se registrará su fecha de salida.
          </p>
          <div className="flex justify-end gap-2">
            <Button variant="outline" onClick={() => setToDelete(null)}>
              Cancelar
            </Button>
            <Button disabled={busy} onClick={onDelete}>
              {busy ? 'Eliminando…' : 'Eliminar'}
            </Button>
          </div>
        </Modal>
      )}
    </div>
  );
}

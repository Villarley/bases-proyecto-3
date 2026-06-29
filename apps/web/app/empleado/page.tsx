'use client';

import { useRouter } from 'next/navigation';
import { useCallback, useEffect, useState } from 'react';
import { TopBar } from '../../components/TopBar';
import { Alert, Button, Input, Modal, Select, Spinner } from '../../components/ui';
import {
  deduccionesMes,
  deduccionesSemana,
  detalleSemana,
  planillaMensual,
  planillaSemanal,
  regresarAdmin,
} from '../../lib/api';
import { colones, fecha, horaMinuto, nombreMes } from '../../lib/format';
import { getSession, setSession } from '../../lib/session';
import type {
  DeduccionRow,
  DetalleDiaRow,
  PlanillaMensualRow,
  PlanillaSemanalRow,
} from '../../lib/types';
import { useAuth } from '../../lib/useAuth';

type Drill =
  | { kind: 'deducciones-semana'; titulo: string; rows: DeduccionRow[] }
  | { kind: 'detalle-semana'; titulo: string; rows: DetalleDiaRow[] }
  | { kind: 'deducciones-mes'; titulo: string; rows: DeduccionRow[] };

export default function EmpleadoPage() {
  const session = useAuth('empleado');
  const router = useRouter();

  const [tab, setTab] = useState<'semanal' | 'mensual'>('semanal');
  const [documento, setDocumento] = useState('');
  const [cantidad, setCantidad] = useState(6);
  const [semanas, setSemanas] = useState<PlanillaSemanalRow[]>([]);
  const [meses, setMeses] = useState<PlanillaMensualRow[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [drill, setDrill] = useState<Drill | null>(null);

  const impersonando = session?.impersonando ?? false;

  useEffect(() => {
    if (session?.empleadoDocumento) setDocumento(session.empleadoDocumento);
  }, [session]);

  const cargar = useCallback(async () => {
    const s = getSession();
    if (!s || !documento.trim()) return;
    setLoading(true);
    setError('');
    try {
      if (tab === 'semanal') {
        const res = await planillaSemanal(s.idUsuario, documento.trim(), cantidad);
        setSemanas(res.items);
      } else {
        const res = await planillaMensual(s.idUsuario, documento.trim(), cantidad);
        setMeses(res.items);
      }
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Error al consultar la planilla.');
    } finally {
      setLoading(false);
    }
  }, [tab, documento, cantidad]);

  useEffect(() => {
    if (session && documento.trim()) void cargar();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [session, tab]);

  async function verDeduccionesSemana(row: PlanillaSemanalRow) {
    const s = getSession();
    if (!s) return;
    try {
      const res = await deduccionesSemana(
        s.idUsuario,
        documento.trim(),
        row.FechaInicioSemana,
      );
      setDrill({
        kind: 'deducciones-semana',
        titulo: `Deducciones de la semana del ${fecha(row.FechaInicioSemana)}`,
        rows: res.items,
      });
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Error al cargar deducciones.');
    }
  }

  async function verDetalleSemana(row: PlanillaSemanalRow) {
    const s = getSession();
    if (!s) return;
    try {
      const res = await detalleSemana(
        s.idUsuario,
        documento.trim(),
        row.FechaInicioSemana,
      );
      setDrill({
        kind: 'detalle-semana',
        titulo: `Detalle de horas de la semana del ${fecha(row.FechaInicioSemana)}`,
        rows: res.items,
      });
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Error al cargar el detalle.');
    }
  }

  async function verDeduccionesMes(row: PlanillaMensualRow) {
    const s = getSession();
    if (!s) return;
    try {
      const res = await deduccionesMes(
        s.idUsuario,
        documento.trim(),
        row.Anio,
        row.Mes,
      );
      setDrill({
        kind: 'deducciones-mes',
        titulo: `Deducciones de ${nombreMes(row.Mes)} ${row.Anio}`,
        rows: res.items,
      });
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Error al cargar deducciones.');
    }
  }

  async function onRegresarAdmin() {
    const s = getSession();
    if (!s) return;
    await regresarAdmin(s.idUsuario).catch(() => undefined);
    setSession({
      ...s,
      tipoUsuario: 'administrador',
      idTipoUsuario: 1,
      empleadoDocumento: undefined,
      empleadoNombre: undefined,
      impersonando: false,
    });
    router.push('/admin');
  }

  if (!session) return null;

  return (
    <div className="min-h-screen">
      <TopBar subtitle="Empleado" />
      <main className="mx-auto max-w-5xl p-6">
        {impersonando && (
          <div className="mb-4 flex flex-wrap items-center justify-between gap-2 rounded-md border border-zinc-400 bg-zinc-100 px-4 py-2 text-sm">
            <span>
              Impersonando a <strong>{session.empleadoNombre}</strong>
            </span>
            <Button variant="outline" onClick={onRegresarAdmin}>
              ← Regresar a administrador
            </Button>
          </div>
        )}

        {/* Filtros */}
        <form
          className="mb-4 flex flex-wrap items-end gap-2"
          onSubmit={(e) => {
            e.preventDefault();
            void cargar();
          }}
        >
          <label className="flex flex-col gap-1 text-sm">
            <span className="font-medium text-zinc-700">Documento</span>
            <Input
              value={documento}
              onChange={(e) => setDocumento(e.target.value)}
              readOnly={impersonando}
              placeholder="Cédula del empleado"
              required
            />
          </label>
          <label className="flex flex-col gap-1 text-sm">
            <span className="font-medium text-zinc-700">
              {tab === 'semanal' ? 'Últimas semanas' : 'Últimos meses'}
            </span>
            <Select
              value={cantidad}
              onChange={(e) => setCantidad(Number(e.target.value))}
            >
              {[4, 6, 8, 12].map((n) => (
                <option key={n} value={n}>
                  {n}
                </option>
              ))}
            </Select>
          </label>
          <Button type="submit" variant="outline">
            Consultar
          </Button>
        </form>

        {/* Tabs */}
        <div className="mb-4 flex gap-2 border-b border-zinc-200">
          {(['semanal', 'mensual'] as const).map((t) => (
            <button
              key={t}
              onClick={() => setTab(t)}
              className={`-mb-px border-b-2 px-3 py-2 text-sm font-medium ${
                tab === t
                  ? 'border-zinc-900 text-zinc-900'
                  : 'border-transparent text-zinc-500 hover:text-zinc-800'
              }`}
            >
              Planilla {t}
            </button>
          ))}
        </div>

        <Alert message={error} />

        {loading ? (
          <Spinner />
        ) : tab === 'semanal' ? (
          <SemanalTable
            rows={semanas}
            onBruto={verDetalleSemana}
            onDeducciones={verDeduccionesSemana}
          />
        ) : (
          <MensualTable rows={meses} onDeducciones={verDeduccionesMes} />
        )}
      </main>

      {drill && (
        <Modal title={drill.titulo} onClose={() => setDrill(null)}>
          {drill.kind === 'detalle-semana' ? (
            <DetalleSemanaTable rows={drill.rows} />
          ) : (
            <DeduccionesTable rows={drill.rows} />
          )}
        </Modal>
      )}
    </div>
  );
}

function Money({ children }: { children: number }) {
  return <span className="tabular-nums">{colones(children)}</span>;
}

function SemanalTable({
  rows,
  onBruto,
  onDeducciones,
}: {
  rows: PlanillaSemanalRow[];
  onBruto: (r: PlanillaSemanalRow) => void;
  onDeducciones: (r: PlanillaSemanalRow) => void;
}) {
  return (
    <div className="overflow-x-auto rounded-lg border border-zinc-200">
      <table className="w-full text-sm">
        <thead className="border-b border-zinc-200 bg-zinc-100 text-left">
          <tr>
            <th className="px-3 py-2 font-medium">Semana</th>
            <th className="px-3 py-2 text-right font-medium">Salario bruto</th>
            <th className="px-3 py-2 text-right font-medium">Deducciones</th>
            <th className="px-3 py-2 text-right font-medium">Salario neto</th>
            <th className="px-3 py-2 text-right font-medium">H. ord.</th>
            <th className="px-3 py-2 text-right font-medium">H. ext.</th>
            <th className="px-3 py-2 text-right font-medium">H. ext. dobles</th>
          </tr>
        </thead>
        <tbody>
          {rows.length === 0 && (
            <tr>
              <td colSpan={7} className="px-3 py-6 text-center text-zinc-500">
                Sin planillas.
              </td>
            </tr>
          )}
          {rows.map((r, i) => (
            <tr key={i} className="border-b border-zinc-100 last:border-0">
              <td className="px-3 py-2">
                {fecha(r.FechaInicioSemana)} – {fecha(r.FechaFinSemana)}
              </td>
              <td className="px-3 py-2 text-right">
                <button
                  className="underline underline-offset-2 hover:text-zinc-600"
                  onClick={() => onBruto(r)}
                >
                  <Money>{r.SalarioBruto}</Money>
                </button>
              </td>
              <td className="px-3 py-2 text-right">
                <button
                  className="underline underline-offset-2 hover:text-zinc-600"
                  onClick={() => onDeducciones(r)}
                >
                  <Money>{r.TotalDeducciones}</Money>
                </button>
              </td>
              <td className="px-3 py-2 text-right">
                <Money>{r.SalarioNeto}</Money>
              </td>
              <td className="px-3 py-2 text-right tabular-nums">
                {r.CantidadHorasOrdinarias}
              </td>
              <td className="px-3 py-2 text-right tabular-nums">
                {r.CantidadHorasExtraNormales}
              </td>
              <td className="px-3 py-2 text-right tabular-nums">
                {r.CantidadHorasExtraDobles}
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}

function MensualTable({
  rows,
  onDeducciones,
}: {
  rows: PlanillaMensualRow[];
  onDeducciones: (r: PlanillaMensualRow) => void;
}) {
  return (
    <div className="overflow-x-auto rounded-lg border border-zinc-200">
      <table className="w-full text-sm">
        <thead className="border-b border-zinc-200 bg-zinc-100 text-left">
          <tr>
            <th className="px-3 py-2 font-medium">Mes</th>
            <th className="px-3 py-2 font-medium">Período</th>
            <th className="px-3 py-2 text-right font-medium">Salario bruto</th>
            <th className="px-3 py-2 text-right font-medium">Deducciones</th>
            <th className="px-3 py-2 text-right font-medium">Salario neto</th>
          </tr>
        </thead>
        <tbody>
          {rows.length === 0 && (
            <tr>
              <td colSpan={5} className="px-3 py-6 text-center text-zinc-500">
                Sin planillas.
              </td>
            </tr>
          )}
          {rows.map((r, i) => (
            <tr key={i} className="border-b border-zinc-100 last:border-0">
              <td className="px-3 py-2">
                {nombreMes(r.Mes)} {r.Anio}
              </td>
              <td className="px-3 py-2 text-zinc-600">
                {fecha(r.FechaInicio)} – {fecha(r.FechaFin)}
              </td>
              <td className="px-3 py-2 text-right">
                <Money>{r.SalarioBrutoMensual}</Money>
              </td>
              <td className="px-3 py-2 text-right">
                <button
                  className="underline underline-offset-2 hover:text-zinc-600"
                  onClick={() => onDeducciones(r)}
                >
                  <Money>{r.TotalDeduccionesMensual}</Money>
                </button>
              </td>
              <td className="px-3 py-2 text-right">
                <Money>{r.SalarioNetoMensual}</Money>
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}

function DeduccionesTable({ rows }: { rows: DeduccionRow[] }) {
  return (
    <table className="w-full text-sm">
      <thead className="border-b border-zinc-200 text-left">
        <tr>
          <th className="px-3 py-2 font-medium">Deducción</th>
          <th className="px-3 py-2 text-right font-medium">% aplicado</th>
          <th className="px-3 py-2 text-right font-medium">Monto</th>
        </tr>
      </thead>
      <tbody>
        {rows.length === 0 && (
          <tr>
            <td colSpan={3} className="px-3 py-6 text-center text-zinc-500">
              Sin deducciones.
            </td>
          </tr>
        )}
        {rows.map((r, i) => (
          <tr key={i} className="border-b border-zinc-100 last:border-0">
            <td className="px-3 py-2">{r.NombreDeduccion}</td>
            <td className="px-3 py-2 text-right tabular-nums">
              {r.PorcentajeAplicado != null
                ? `${(r.PorcentajeAplicado * 100).toFixed(2)}%`
                : '-'}
            </td>
            <td className="px-3 py-2 text-right">
              <Money>{r.MontoDeduccion}</Money>
            </td>
          </tr>
        ))}
      </tbody>
    </table>
  );
}

function DetalleSemanaTable({ rows }: { rows: DetalleDiaRow[] }) {
  return (
    <div className="overflow-x-auto">
      <table className="w-full text-sm">
        <thead className="border-b border-zinc-200 text-left">
          <tr>
            <th className="px-2 py-2 font-medium">Fecha</th>
            <th className="px-2 py-2 font-medium">Entrada</th>
            <th className="px-2 py-2 font-medium">Salida</th>
            <th className="px-2 py-2 text-right font-medium">H. ord.</th>
            <th className="px-2 py-2 text-right font-medium">Monto ord.</th>
            <th className="px-2 py-2 text-right font-medium">H. ext.</th>
            <th className="px-2 py-2 text-right font-medium">Monto ext.</th>
            <th className="px-2 py-2 text-right font-medium">H. dobles</th>
            <th className="px-2 py-2 text-right font-medium">Monto doble</th>
          </tr>
        </thead>
        <tbody>
          {rows.length === 0 && (
            <tr>
              <td colSpan={9} className="px-2 py-6 text-center text-zinc-500">
                Sin asistencias.
              </td>
            </tr>
          )}
          {rows.map((r, i) => (
            <tr key={i} className="border-b border-zinc-100 last:border-0">
              <td className="px-2 py-2">{fecha(r.Fecha)}</td>
              <td className="px-2 py-2">{horaMinuto(r.HoraEntrada)}</td>
              <td className="px-2 py-2">{horaMinuto(r.HoraSalida)}</td>
              <td className="px-2 py-2 text-right tabular-nums">{r.HorasOrdinarias}</td>
              <td className="px-2 py-2 text-right">
                <Money>{r.MontoOrdinario}</Money>
              </td>
              <td className="px-2 py-2 text-right tabular-nums">
                {r.HorasExtraNormales}
              </td>
              <td className="px-2 py-2 text-right">
                <Money>{r.MontoExtraNormal}</Money>
              </td>
              <td className="px-2 py-2 text-right tabular-nums">{r.HorasExtraDobles}</td>
              <td className="px-2 py-2 text-right">
                <Money>{r.MontoExtraDoble}</Money>
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}

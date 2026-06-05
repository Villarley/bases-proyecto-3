import Link from 'next/link';

export default function HomePage() {
  return (
    <main className="mx-auto flex min-h-screen max-w-2xl flex-col justify-center gap-6 p-6">
      <h1 className="text-3xl font-semibold tracking-tight">Planilla Obrera</h1>
      <p className="text-zinc-600">
        Control de asistencia y planilla obrera — IC-4301 Bases de Datos I.
      </p>
      <Link
        href="/login"
        className="inline-flex w-fit rounded-lg bg-zinc-900 px-4 py-2 text-sm font-medium text-white hover:bg-zinc-800"
      >
        Ir a inicio de sesión
      </Link>
    </main>
  );
}

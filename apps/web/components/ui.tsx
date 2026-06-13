'use client';

import type {
  ButtonHTMLAttributes,
  InputHTMLAttributes,
  ReactNode,
  SelectHTMLAttributes,
} from 'react';

export function Button({
  variant = 'solid',
  className = '',
  ...props
}: ButtonHTMLAttributes<HTMLButtonElement> & {
  variant?: 'solid' | 'outline' | 'ghost' | 'link';
}) {
  const base =
    'inline-flex items-center justify-center rounded-md px-3 py-1.5 text-sm font-medium transition disabled:opacity-40 disabled:cursor-not-allowed';
  const variants: Record<string, string> = {
    solid: 'bg-zinc-900 text-white hover:bg-zinc-700',
    outline: 'border border-zinc-400 text-zinc-900 hover:bg-zinc-100',
    ghost: 'text-zinc-700 hover:bg-zinc-100',
    link: 'text-zinc-900 underline underline-offset-2 hover:text-zinc-600 px-0 py-0',
  };
  return (
    <button className={`${base} ${variants[variant]} ${className}`} {...props} />
  );
}

export function Field({
  label,
  children,
}: {
  label: string;
  children: ReactNode;
}) {
  return (
    <label className="flex flex-col gap-1 text-sm">
      <span className="font-medium text-zinc-700">{label}</span>
      {children}
    </label>
  );
}

export function Input(props: InputHTMLAttributes<HTMLInputElement>) {
  return (
    <input
      {...props}
      className={`rounded-md border border-zinc-300 bg-white px-3 py-1.5 text-sm outline-none focus:border-zinc-900 ${props.className ?? ''}`}
    />
  );
}

export function Select(props: SelectHTMLAttributes<HTMLSelectElement>) {
  return (
    <select
      {...props}
      className={`rounded-md border border-zinc-300 bg-white px-3 py-1.5 text-sm outline-none focus:border-zinc-900 ${props.className ?? ''}`}
    />
  );
}

export function Alert({ message }: { message: string }) {
  if (!message) return null;
  return (
    <div className="rounded-md border border-zinc-400 bg-zinc-100 px-3 py-2 text-sm text-zinc-800">
      {message}
    </div>
  );
}

export function Modal({
  title,
  onClose,
  children,
}: {
  title: string;
  onClose: () => void;
  children: ReactNode;
}) {
  return (
    <div className="fixed inset-0 z-50 flex items-start justify-center overflow-y-auto bg-zinc-900/40 p-4">
      <div className="mt-16 w-full max-w-3xl rounded-lg border border-zinc-300 bg-white shadow-lg">
        <div className="flex items-center justify-between border-b border-zinc-200 px-4 py-3">
          <h2 className="text-base font-semibold">{title}</h2>
          <Button variant="ghost" onClick={onClose} aria-label="Cerrar">
            ✕
          </Button>
        </div>
        <div className="p-4">{children}</div>
      </div>
    </div>
  );
}

export function Spinner({ label = 'Cargando…' }: { label?: string }) {
  return <p className="text-sm text-zinc-500">{label}</p>;
}

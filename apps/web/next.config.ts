import path from 'path';
import type { NextConfig } from 'next';

const nextConfig: NextConfig = {
  /** Monorepo root — avoids wrong inference when parent dirs have another lockfile */
  outputFileTracingRoot: path.join(__dirname, '..', '..'),
  transpilePackages: ['@planilla-obrera/types'],
};

export default nextConfig;

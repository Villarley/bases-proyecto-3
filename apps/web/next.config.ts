import path from 'path';
import type { NextConfig } from 'next';

const nextConfig: NextConfig = {
  outputFileTracingRoot: path.join(__dirname, '..', '..'),
  transpilePackages: ['@planilla-obrera/types'],
};

export default nextConfig;

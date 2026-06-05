import {
  Injectable,
  InternalServerErrorException,
  Logger,
  OnModuleDestroy,
  OnModuleInit,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import * as sql from 'mssql';

@Injectable()
export class DatabaseService implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(DatabaseService.name);
  private pool: sql.ConnectionPool | null = null;

  constructor(private readonly config: ConfigService) {}

  async onModuleInit(): Promise<void> {
    const host = this.config.get<string>('DB_HOST');
    const port = Number(this.config.get<string>('DB_PORT') ?? '1433');
    const database = this.config.get<string>('DB_NAME') ?? 'planilla_obrera';
    const user = this.config.get<string>('DB_USER');
    const password = this.config.get<string>('DB_PASSWORD');

    if (!host || !user || password === undefined || password === '') {
      this.logger.warn('Database env incomplete; SQL pool not started.');
      return;
    }

    const poolConfig: sql.config = {
      server: host,
      port,
      database,
      user,
      password,
      pool: { max: 10, min: 0, idleTimeoutMillis: 30000 },
      options: {
        encrypt: true,
        trustServerCertificate: true,
      },
    };

    this.pool = new sql.ConnectionPool(poolConfig);
    try {
      await this.pool.connect();
      this.logger.log('Pool de SQL Server conectado.');
    } catch (err) {
      this.logger.error('Falló la conexión a SQL Server', err instanceof Error ? err.stack : err);
      await this.pool.close().catch(() => undefined);
      this.pool = null;
    }
  }

  async onModuleDestroy(): Promise<void> {
    if (this.pool) {
      await this.pool.close();
      this.pool = null;
    }
  }

  getConnectionInfo() {
    return {
      host: this.config.get<string>('DB_HOST'),
      port: this.config.get<string>('DB_PORT'),
      database: this.config.get<string>('DB_NAME') ?? 'planilla_obrera',
      user: this.config.get<string>('DB_USER'),
    };
  }

  isReady(): boolean {
    return this.pool !== null && this.pool.connected;
  }

  private requirePool(): sql.ConnectionPool {
    if (!this.pool || !this.pool.connected) {
      throw new InternalServerErrorException({
        resultCode: 50008,
        message: 'Base de datos no disponible.',
      });
    }
    return this.pool;
  }
}

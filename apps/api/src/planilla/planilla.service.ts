import { Injectable } from '@nestjs/common';
import { throwIfSpError } from '../common/sp-error';
import { DatabaseService } from '../database/database.service';
import { DeduccionesMesQuery } from './dto/deducciones-mes.query';
import { DeduccionesSemanaQuery } from './dto/deducciones-semana.query';
import { DetalleSemanaQuery } from './dto/detalle-semana.query';
import { MensualQuery } from './dto/mensual.query';
import { SemanalQuery } from './dto/semanal.query';

@Injectable()
export class PlanillaService {
  constructor(private readonly database: DatabaseService) {}

  async semanal(query: SemanalQuery, ip: string) {
    const result = await this.database.runPlanillaConsultarSemanal(
      query.idUsuario,
      ip,
      query.documento,
      query.cantidadSemanas ?? null,
    );

    await throwIfSpError(result.resultCode, this.database);
    return { items: result.items };
  }

  async deduccionesSemana(query: DeduccionesSemanaQuery, ip: string) {
    const result = await this.database.runPlanillaConsultarDeduccionesSemana(
      query.idUsuario,
      ip,
      query.documento,
      new Date(query.fechaInicioSemana),
    );

    await throwIfSpError(result.resultCode, this.database);
    return { items: result.items };
  }

  async detalleSemana(query: DetalleSemanaQuery, ip: string) {
    const result = await this.database.runPlanillaConsultarDetalleSemana(
      query.idUsuario,
      ip,
      query.documento,
      new Date(query.fechaInicioSemana),
    );

    await throwIfSpError(result.resultCode, this.database);
    return { items: result.items };
  }

  async mensual(query: MensualQuery, ip: string) {
    const result = await this.database.runPlanillaConsultarMensual(
      query.idUsuario,
      ip,
      query.documento,
      query.cantidadMeses ?? null,
    );

    await throwIfSpError(result.resultCode, this.database);
    return { items: result.items };
  }

  async deduccionesMes(query: DeduccionesMesQuery, ip: string) {
    const result = await this.database.runPlanillaConsultarDeduccionesMes(
      query.idUsuario,
      ip,
      query.documento,
      query.anio,
      query.mes,
    );

    await throwIfSpError(result.resultCode, this.database);
    return { items: result.items };
  }
}

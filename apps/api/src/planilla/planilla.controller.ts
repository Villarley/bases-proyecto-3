import { Controller, Get, Query } from '@nestjs/common';
import { ClientIp } from '../common/client-ip.decorator';
import { DeduccionesMesQuery } from './dto/deducciones-mes.query';
import { DeduccionesSemanaQuery } from './dto/deducciones-semana.query';
import { DetalleSemanaQuery } from './dto/detalle-semana.query';
import { MensualQuery } from './dto/mensual.query';
import { SemanalQuery } from './dto/semanal.query';
import { PlanillaService } from './planilla.service';

@Controller('planilla')
export class PlanillaController {
  constructor(private readonly planillaService: PlanillaService) {}

  @Get('semanal')
  semanal(@Query() query: SemanalQuery, @ClientIp() ip: string) {
    return this.planillaService.semanal(query, ip);
  }

  @Get('semanal/deducciones')
  deduccionesSemana(
    @Query() query: DeduccionesSemanaQuery,
    @ClientIp() ip: string,
  ) {
    return this.planillaService.deduccionesSemana(query, ip);
  }

  @Get('semanal/detalle')
  detalleSemana(
    @Query() query: DetalleSemanaQuery,
    @ClientIp() ip: string,
  ) {
    return this.planillaService.detalleSemana(query, ip);
  }

  @Get('mensual')
  mensual(@Query() query: MensualQuery, @ClientIp() ip: string) {
    return this.planillaService.mensual(query, ip);
  }

  @Get('mensual/deducciones')
  deduccionesMes(
    @Query() query: DeduccionesMesQuery,
    @ClientIp() ip: string,
  ) {
    return this.planillaService.deduccionesMes(query, ip);
  }
}

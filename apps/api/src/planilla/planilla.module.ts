import { Module } from '@nestjs/common';
import { PlanillaController } from './planilla.controller';
import { PlanillaService } from './planilla.service';

@Module({
  controllers: [PlanillaController],
  providers: [PlanillaService],
})
export class PlanillaModule {}

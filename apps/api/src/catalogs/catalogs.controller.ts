import { Controller, Get } from '@nestjs/common';
import { CatalogsService } from './catalogs.service';

@Controller('catalogos')
export class CatalogsController {
  constructor(private readonly catalogsService: CatalogsService) {}

  @Get('puestos')
  listarPuestos() {
    return this.catalogsService.listarPuestos();
  }

  @Get('departamentos')
  listarDepartamentos() {
    return this.catalogsService.listarDepartamentos();
  }

  @Get('tipos-documento')
  listarTiposDocumento() {
    return this.catalogsService.listarTiposDocumento();
  }
}

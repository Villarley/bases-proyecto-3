import { Injectable } from '@nestjs/common';
import { throwIfSpError } from '../common/sp-error';
import { DatabaseService } from '../database/database.service';

@Injectable()
export class CatalogsService {
  constructor(private readonly database: DatabaseService) {}

  async listarPuestos() {
    const result = await this.database.runCatalogoListarPuestos();
    await throwIfSpError(result.resultCode, this.database);
    return { items: result.items };
  }

  async listarDepartamentos() {
    const result = await this.database.runCatalogoListarDepartamentos();
    await throwIfSpError(result.resultCode, this.database);
    return { items: result.items };
  }

  async listarTiposDocumento() {
    const result = await this.database.runCatalogoListarTiposDocumento();
    await throwIfSpError(result.resultCode, this.database);
    return { items: result.items };
  }
}

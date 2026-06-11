import { Injectable } from '@nestjs/common';
import { throwIfSpError } from '../common/sp-error';
import { DatabaseService } from '../database/database.service';
import { CreateEmpleadoDto } from './dto/create-empleado.dto';
import { DeleteEmpleadoDto } from './dto/delete-empleado.dto';
import { UpdateEmpleadoDto } from './dto/update-empleado.dto';

@Injectable()
export class EmployeesService {
  constructor(private readonly database: DatabaseService) {}

  async listar(idUsuario: number, ip: string, filtro?: string) {
    const result =
      filtro !== undefined && filtro.trim() !== ''
        ? await this.database.runEmpleadoListarConFiltro(
            idUsuario,
            ip,
            filtro,
          )
        : await this.database.runEmpleadoListar(idUsuario, ip);

    await throwIfSpError(result.resultCode, this.database);
    return { items: result.items };
  }

  async crear(dto: CreateEmpleadoDto, ip: string) {
    const resultCode = await this.database.runEmpleadoInsertar(
      dto.idUsuario,
      ip,
      dto.nombre,
      dto.valorDocumentoIdentidad,
      dto.idTipoDocumento ?? null,
      dto.idDepartamento ?? null,
      dto.nombrePuesto,
      dto.numeroCuentaBanco ?? '',
      dto.fechaIngreso ? new Date(dto.fechaIngreso) : null,
      dto.username ?? null,
      dto.password ?? null,
    );

    await throwIfSpError(resultCode, this.database);
    return { resultCode: 0 };
  }

  async editar(
    valorDocumentoIdentidad: string,
    dto: UpdateEmpleadoDto,
    ip: string,
  ) {
    const resultCode = await this.database.runEmpleadoEditar(
      dto.idUsuario,
      ip,
      valorDocumentoIdentidad,
      dto.nuevoNombre ?? null,
      dto.nuevoValorDocumentoIdentidad ?? null,
      dto.nombrePuesto ?? null,
      dto.idDepartamento ?? null,
      dto.numeroCuentaBanco ?? null,
    );

    await throwIfSpError(resultCode, this.database);
    return { resultCode: 0 };
  }

  async eliminar(
    valorDocumentoIdentidad: string,
    dto: DeleteEmpleadoDto,
    ip: string,
  ) {
    const resultCode = await this.database.runEmpleadoEliminar(
      dto.idUsuario,
      ip,
      valorDocumentoIdentidad,
      dto.fechaSalida ? new Date(dto.fechaSalida) : null,
    );

    await throwIfSpError(resultCode, this.database);
    return { resultCode: 0 };
  }

  async impersonar(
    valorDocumentoIdentidad: string,
    idUsuarioAdmin: number,
    ip: string,
  ) {
    const result = await this.database.runEmpleadoImpersonar(
      idUsuarioAdmin,
      ip,
      valorDocumentoIdentidad,
    );

    await throwIfSpError(result.resultCode, this.database);
    return result.item;
  }

  async regresarAdmin(idUsuario: number, ip: string) {
    const resultCode = await this.database.runEmpleadoRegresarAdmin(
      idUsuario,
      ip,
    );

    await throwIfSpError(resultCode, this.database);
    return { resultCode: 0 };
  }
}

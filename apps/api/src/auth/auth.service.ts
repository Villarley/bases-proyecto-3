import { Injectable } from '@nestjs/common';
import { throwIfSpError } from '../common/sp-error';
import { DatabaseService } from '../database/database.service';
import { LoginDto } from './dto/login.dto';

@Injectable()
export class AuthService {
  constructor(private readonly database: DatabaseService) {}

  async login(dto: LoginDto, ip: string) {
    const result = await this.database.runAuthLogin(
      dto.username,
      dto.password,
      ip,
    );
    await throwIfSpError(result.resultCode, this.database);

    const idTipoUsuario = result.idTipoUsuario!;

    return {
      idUsuario: result.idUsuario!,
      idTipoUsuario,
      tipoUsuario: idTipoUsuario === 1 ? 'administrador' : 'empleado',
      idEmpleado: result.idEmpleado,
    };
  }

  async logout(idUsuario: number, ip: string) {
    const resultCode = await this.database.runAuthLogout(idUsuario, ip);
    await throwIfSpError(resultCode, this.database);
    return { resultCode: 0 };
  }
}

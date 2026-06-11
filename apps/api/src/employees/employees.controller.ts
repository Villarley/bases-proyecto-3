import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Post,
  Put,
  Query,
} from '@nestjs/common';
import { ClientIp } from '../common/client-ip.decorator';
import { CreateEmpleadoDto } from './dto/create-empleado.dto';
import { DeleteEmpleadoDto } from './dto/delete-empleado.dto';
import { ImpersonarDto } from './dto/impersonar.dto';
import { ListEmpleadosQuery } from './dto/list-empleados.query';
import { RegresarAdminDto } from './dto/regresar-admin.dto';
import { UpdateEmpleadoDto } from './dto/update-empleado.dto';
import { EmployeesService } from './employees.service';

@Controller('empleados')
export class EmployeesController {
  constructor(private readonly employeesService: EmployeesService) {}

  @Get()
  listar(@Query() query: ListEmpleadosQuery, @ClientIp() ip: string) {
    return this.employeesService.listar(query.idUsuario, ip, query.filtro);
  }

  @Post()
  crear(@Body() dto: CreateEmpleadoDto, @ClientIp() ip: string) {
    return this.employeesService.crear(dto, ip);
  }

  @Put(':documento')
  editar(
    @Param('documento') documento: string,
    @Body() dto: UpdateEmpleadoDto,
    @ClientIp() ip: string,
  ) {
    return this.employeesService.editar(documento, dto, ip);
  }

  @Post('regresar-admin')
  regresarAdmin(@Body() dto: RegresarAdminDto, @ClientIp() ip: string) {
    return this.employeesService.regresarAdmin(dto.idUsuario, ip);
  }

  @Delete(':documento')
  eliminar(
    @Param('documento') documento: string,
    @Body() dto: DeleteEmpleadoDto,
    @ClientIp() ip: string,
  ) {
    return this.employeesService.eliminar(documento, dto, ip);
  }

  @Post(':documento/impersonar')
  impersonar(
    @Param('documento') documento: string,
    @Body() dto: ImpersonarDto,
    @ClientIp() ip: string,
  ) {
    return this.employeesService.impersonar(
      documento,
      dto.idUsuarioAdmin,
      ip,
    );
  }
}

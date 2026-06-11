import { Type } from 'class-transformer';
import { IsInt, IsOptional, IsString } from 'class-validator';

export class ListEmpleadosQuery {
  @Type(() => Number)
  @IsInt()
  idUsuario!: number;

  @IsOptional()
  @IsString()
  filtro?: string;
}

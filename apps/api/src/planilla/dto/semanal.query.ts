import { Type } from 'class-transformer';
import { IsInt, IsOptional, IsString } from 'class-validator';

export class SemanalQuery {
  @Type(() => Number)
  @IsInt()
  idUsuario!: number;

  @IsString()
  documento!: string;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  cantidadSemanas?: number;
}

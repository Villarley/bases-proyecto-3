import { Type } from 'class-transformer';
import { IsInt, IsOptional, IsString } from 'class-validator';

export class MensualQuery {
  @Type(() => Number)
  @IsInt()
  idUsuario!: number;

  @IsString()
  documento!: string;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  cantidadMeses?: number;
}

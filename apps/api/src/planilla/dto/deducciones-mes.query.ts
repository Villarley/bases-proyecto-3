import { Type } from 'class-transformer';
import { IsInt, IsString } from 'class-validator';

export class DeduccionesMesQuery {
  @Type(() => Number)
  @IsInt()
  idUsuario!: number;

  @IsString()
  documento!: string;

  @Type(() => Number)
  @IsInt()
  anio!: number;

  @Type(() => Number)
  @IsInt()
  mes!: number;
}

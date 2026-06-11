import { Type } from 'class-transformer';
import { IsDateString, IsInt, IsString } from 'class-validator';

export class DetalleSemanaQuery {
  @Type(() => Number)
  @IsInt()
  idUsuario!: number;

  @IsString()
  documento!: string;

  @IsDateString()
  fechaInicioSemana!: string;
}

import { IsDateString, IsInt, IsOptional } from 'class-validator';

export class DeleteEmpleadoDto {
  @IsInt()
  idUsuario!: number;

  @IsOptional()
  @IsDateString()
  fechaSalida?: string;
}

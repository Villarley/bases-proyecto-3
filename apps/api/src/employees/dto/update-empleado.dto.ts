import { IsInt, IsOptional, IsString } from 'class-validator';

export class UpdateEmpleadoDto {
  @IsInt()
  idUsuario!: number;

  @IsOptional()
  @IsString()
  nuevoNombre?: string;

  @IsOptional()
  @IsString()
  nuevoValorDocumentoIdentidad?: string;

  @IsOptional()
  @IsString()
  nombrePuesto?: string;

  @IsOptional()
  @IsInt()
  idDepartamento?: number;

  @IsOptional()
  @IsString()
  numeroCuentaBanco?: string;
}

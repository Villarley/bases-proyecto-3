import {
  IsDateString,
  IsInt,
  IsNotEmpty,
  IsOptional,
  IsString,
} from 'class-validator';

export class CreateEmpleadoDto {
  @IsInt()
  idUsuario!: number;

  @IsString()
  @IsNotEmpty()
  nombre!: string;

  @IsString()
  @IsNotEmpty()
  valorDocumentoIdentidad!: string;

  @IsString()
  @IsNotEmpty()
  nombrePuesto!: string;

  @IsOptional()
  @IsString()
  numeroCuentaBanco?: string;

  @IsOptional()
  @IsInt()
  idTipoDocumento?: number;

  @IsOptional()
  @IsInt()
  idDepartamento?: number;

  @IsOptional()
  @IsDateString()
  fechaIngreso?: string;

  @IsOptional()
  @IsString()
  username?: string;

  @IsOptional()
  @IsString()
  password?: string;
}

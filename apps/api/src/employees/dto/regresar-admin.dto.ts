import { IsInt } from 'class-validator';

export class RegresarAdminDto {
  @IsInt()
  idUsuario!: number;
}

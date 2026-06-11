import { IsInt } from 'class-validator';

export class LogoutDto {
  @IsInt()
  idUsuario!: number;
}

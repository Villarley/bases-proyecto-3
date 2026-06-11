import { IsInt } from 'class-validator';

export class ImpersonarDto {
  @IsInt()
  idUsuarioAdmin!: number;
}

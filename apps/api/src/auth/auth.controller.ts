import { Body, Controller, Post } from '@nestjs/common';
import { ClientIp } from '../common/client-ip.decorator';
import { AuthService } from './auth.service';
import { LoginDto } from './dto/login.dto';
import { LogoutDto } from './dto/logout.dto';

@Controller('auth')
export class AuthController {
  constructor(private readonly authService: AuthService) {}

  @Post('login')
  login(@Body() dto: LoginDto, @ClientIp() ip: string) {
    return this.authService.login(dto, ip);
  }

  @Post('logout')
  logout(@Body() dto: LogoutDto, @ClientIp() ip: string) {
    return this.authService.logout(dto.idUsuario, ip);
  }
}

import { Injectable } from '@nestjs/common';
import { DatabaseService } from './database/database.service';

@Injectable()
export class AppService {
  constructor(private readonly databaseService: DatabaseService) {}

  getHealth() {
    return {
      status: 'ok' as const,
      db: this.databaseService.isReady(),
    };
  }
}

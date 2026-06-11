import { HttpException, HttpStatus } from '@nestjs/common';
import { DatabaseService } from '../database/database.service';

export function httpStatusForResultCode(resultCode: number): HttpStatus {
  switch (resultCode) {
    case 50001:
    case 50002:
      return HttpStatus.UNAUTHORIZED;
    case 50004:
    case 50006:
    case 50007:
    case 50009:
    case 50010:
    case 50015:
      return HttpStatus.UNPROCESSABLE_ENTITY;
    case 50003:
    case 50005:
    case 50012:
    case 50013:
      return HttpStatus.NOT_FOUND;
    case 50008:
    default:
      return HttpStatus.INTERNAL_SERVER_ERROR;
  }
}

export async function throwIfSpError(
  resultCode: number,
  database: DatabaseService,
): Promise<void> {
  if (resultCode !== 0) {
    const message = await database.getErrorDescription(resultCode);
    throw new HttpException(
      { resultCode, message },
      httpStatusForResultCode(resultCode),
    );
  }
}

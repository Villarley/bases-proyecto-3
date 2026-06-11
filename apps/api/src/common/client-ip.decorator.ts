import { createParamDecorator, ExecutionContext } from '@nestjs/common';
import type { Request } from 'express';

export const ClientIp = createParamDecorator(
  (_data: unknown, ctx: ExecutionContext): string => {
    const req = ctx.switchToHttp().getRequest<Request>();
    const forwarded = req.headers['x-forwarded-for'];

    if (typeof forwarded === 'string' && forwarded.trim() !== '') {
      const first = forwarded.split(',')[0]?.trim();
      if (first) {
        return first;
      }
    }

    if (Array.isArray(forwarded) && forwarded.length > 0) {
      const first = forwarded[0]?.trim();
      if (first) {
        return first;
      }
    }

    if (req.ip && req.ip.trim() !== '') {
      return req.ip;
    }

    return '0.0.0.0';
  },
);

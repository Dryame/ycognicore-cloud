import { HttpInterceptorFn } from '@angular/common/http';
import { inject } from '@angular/core';
import { TokenService } from '../auth/token.service';

/**
 * Ajoute Authorization: Bearer depuis TokenService (memoire, D-13).
 * withCredentials pour /api/auth/* et /api/mfa/* (cookie refresh HttpOnly).
 */
export const jwtInterceptor: HttpInterceptorFn = (req, next) => {
  const tokenService = inject(TokenService);
  const token = tokenService.get();

  const needsCredentials =
    req.url.includes('/api/auth/') || req.url.includes('/api/mfa/');

  let cloned = req;
  if (token) {
    cloned = cloned.clone({
      setHeaders: { Authorization: `Bearer ${token}` },
    });
  }
  if (needsCredentials && !cloned.withCredentials) {
    cloned = cloned.clone({ withCredentials: true });
  }
  return next(cloned);
};

import { HttpInterceptorFn } from '@angular/common/http';
import { inject } from '@angular/core';
import { AuthService } from '../auth/auth.service';

export const jwtInterceptor: HttpInterceptorFn = (req, next) => {
  const auth = inject(AuthService);
  const token = auth.accessToken;
  const user = auth.currentUser;

  let headers = req.headers;
  if (token) {
    headers = headers.set('Authorization', `Bearer ${token}`);
  }
  if (user?.tenantCode && !headers.has('X-Tenant-Code')) {
    headers = headers.set('X-Tenant-Code', user.tenantCode);
  }

  return next(req.clone({ headers }));
};

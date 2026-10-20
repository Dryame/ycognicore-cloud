import { ApplicationConfig, provideZonelessChangeDetection } from '@angular/core';
import { provideRouter } from '@angular/router';
import { provideHttpClient, withInterceptors } from '@angular/common/http';

import { routes } from './app.routes';
import { csrfInterceptor } from './core/http/csrf.interceptor';
import { jwtInterceptor } from './core/http/jwt.interceptor';
import { authRefreshInterceptor } from './core/http/auth-refresh.interceptor';

export const appConfig: ApplicationConfig = {
  providers: [
    provideZonelessChangeDetection(),
    provideRouter(routes),
    provideHttpClient(
      withInterceptors([
        csrfInterceptor,
        jwtInterceptor,
        authRefreshInterceptor,
      ])
    ),
  ],
};

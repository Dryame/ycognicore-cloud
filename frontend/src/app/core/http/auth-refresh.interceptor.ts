import { HttpInterceptorFn, HttpErrorResponse } from '@angular/common/http';
import { inject } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Router } from '@angular/router';
import { catchError, switchMap, throwError, BehaviorSubject, filter, take } from 'rxjs';
import { TokenService } from '../auth/token.service';
import { environment } from '../../../environments/environment';

/**
 * Interceptor refresh automatique (D-13 partiel, C44).
 * Sur 401 : POST /api/auth/refresh avec refreshToken de sessionStorage,
 * rejoue la requete initiale avec le nouveau token.
 */

let refreshInProgress = false;
const refreshDone$ = new BehaviorSubject<boolean>(false);

export const authRefreshInterceptor: HttpInterceptorFn = (req, next) => {
  const tokenService = inject(TokenService);
  const http = inject(HttpClient);
  const router = inject(Router);

  if (req.url.includes('/api/auth/login') || req.url.includes('/api/auth/refresh')) {
    return next(req);
  }

  return next(req).pipe(
    catchError((error: HttpErrorResponse) => {
      if (error.status !== 401) {
        return throwError(() => error);
      }

      if (refreshInProgress) {
        return refreshDone$.pipe(
          filter(done => done),
          take(1),
          switchMap(() => {
            const newToken = tokenService.get();
            if (!newToken) return throwError(() => error);
            return next(req.clone({
              setHeaders: { Authorization: `Bearer ${newToken}` },
            }));
          })
        );
      }

      refreshInProgress = true;
      refreshDone$.next(false);

      const storedRefresh = tokenService.getRefresh();
      if (!storedRefresh) {
        refreshInProgress = false;
        refreshDone$.next(true);
        router.navigate(['/login']);
        return throwError(() => error);
      }

      return http.post<any>(
        `${environment.apiUrl}/api/auth/refresh`,
        { refreshToken: storedRefresh },
        { withCredentials: true }
      ).pipe(
        switchMap((res) => {
          refreshInProgress = false;
          refreshDone$.next(true);

          if (!res.accessToken) {
            router.navigate(['/login']);
            return throwError(() => error);
          }

          tokenService.set(res.accessToken);
          if (res.refreshToken) tokenService.setRefresh(res.refreshToken);

          return next(req.clone({
            setHeaders: { Authorization: `Bearer ${res.accessToken}` },
          }));
        }),
        catchError((refreshError) => {
          refreshInProgress = false;
          refreshDone$.next(true);
          tokenService.clearAll();
          router.navigate(['/login']);
          return throwError(() => refreshError);
        })
      );
    })
  );
};

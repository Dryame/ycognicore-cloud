import { inject } from '@angular/core';
import { CanActivateFn, Router } from '@angular/router';
import { AuthService } from './auth.service';

/**
 * Guard synchrone minimaliste.
 * Laisse passer si l'utilisateur est memorise (localStorage).
 * Le refresh des tokens est gere par authRefreshInterceptor (401 → refresh → retry).
 * Ref. : D-13 partiel (C44).
 */
export const authGuard: CanActivateFn = () => {
  const auth = inject(AuthService);
  const router = inject(Router);

  if (auth.currentUser() !== null) {
    return true;
  }
  router.navigate(['/login']);
  return false;
};

import { inject } from '@angular/core';
import { ActivatedRouteSnapshot, CanActivateFn, Router } from '@angular/router';
import { AuthService } from './auth.service';

export const roleGuard: CanActivateFn = (route: ActivatedRouteSnapshot) => {
  const auth = inject(AuthService);
  const router = inject(Router);
  const user = auth.currentUser;
  const allowed = (route.data?.['roles'] as string[] | undefined) ?? [];

  if (!user) {
    router.navigate(['/login']);
    return false;
  }
  if (allowed.length === 0 || allowed.includes(user.userType)) {
    return true;
  }
  router.navigate([user.redirectUrl || '/login']);
  return false;
};

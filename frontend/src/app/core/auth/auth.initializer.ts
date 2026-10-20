import { inject, provideAppInitializer } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { AuthService } from './auth.service';
import { TokenService } from './token.service';
import { environment } from '../../../environments/environment';
import { firstValueFrom } from 'rxjs';

export function provideAuthInitializer() {
  return provideAppInitializer(() => {
    const auth = inject(AuthService);
    const tokenService = inject(TokenService);
    const http = inject(HttpClient);

    if (!auth.currentUser()) {
      return Promise.resolve();
    }

    // Le cookie HttpOnly refresh_token sera envoye automatiquement
    return firstValueFrom(
      http.post<any>(
        `${environment.apiUrl}/api/auth/refresh`,
        {},
        { withCredentials: true }
      )
    )
      .then((res) => {
        if (res?.accessToken) {
          tokenService.set(res.accessToken);
        }
      })
      .catch(() => {
        tokenService.clear();
      });
  });
}

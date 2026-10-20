import { Injectable, signal } from '@angular/core';

/**
 * Gestion des jetons (D-13 partiel).
 * - Access token : en memoire (jamais persiste) — D-13 contrainte 2
 * - Refresh token : sessionStorage (workaround temporaire)
 *   → survit au F5, efface a la fermeture de l'onglet
 *   → version finale = cookie HttpOnly (P4, C44)
 */
@Injectable({ providedIn: 'root' })
export class TokenService {
  private readonly _accessToken = signal<string | null>(null);
  readonly accessToken = this._accessToken.asReadonly();

  private readonly REFRESH_KEY = 'ycc_refresh_tmp';

  // ---- Access token (memoire) ----
  set(token: string | null): void { this._accessToken.set(token); }
  get(): string | null { return this._accessToken(); }
  clear(): void { this._accessToken.set(null); }
  has(): boolean { return this._accessToken() !== null; }

  // ---- Refresh token (sessionStorage temporaire) ----
  setRefresh(token: string | null): void {
    if (token) sessionStorage.setItem(this.REFRESH_KEY, token);
    else sessionStorage.removeItem(this.REFRESH_KEY);
  }
  getRefresh(): string | null {
    return sessionStorage.getItem(this.REFRESH_KEY);
  }
  clearRefresh(): void {
    sessionStorage.removeItem(this.REFRESH_KEY);
  }

  clearAll(): void {
    this.clear();
    this.clearRefresh();
  }
}

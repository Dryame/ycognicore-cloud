import { Injectable, signal } from '@angular/core';

/**
 * Access token en memoire (D-13, contrainte 2).
 * Jamais persiste — perdu au rechargement.
 * La route /refresh devient le point de reprise de session.
 */
@Injectable({ providedIn: 'root' })
export class TokenService {
  private readonly _accessToken = signal<string | null>(null);

  readonly accessToken = this._accessToken.asReadonly();

  set(token: string | null): void {
    this._accessToken.set(token);
  }

  get(): string | null {
    return this._accessToken();
  }

  clear(): void {
    this._accessToken.set(null);
  }

  has(): boolean {
    return this._accessToken() !== null;
  }
}

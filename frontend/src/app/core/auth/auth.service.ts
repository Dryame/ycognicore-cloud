import { Injectable, inject, signal } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Router } from '@angular/router';
import { Observable, tap } from 'rxjs';
import { environment } from '../../../environments/environment';
import {
  LoginRequest, LoginResponse, RefreshResponse, UserInfo,
} from '../models/login.model';
import { TokenService } from './token.service';

/**
 * Authentification — D-13 :
 *  - access token en memoire (TokenService)
 *  - refresh token en cookie HttpOnly (emis par le backend)
 *  - withCredentials sur /api/auth/* et /api/mfa/*
 */
@Injectable({ providedIn: 'root' })
export class AuthService {
  private readonly http = inject(HttpClient);
  private readonly router = inject(Router);
  private readonly tokenService = inject(TokenService);

  private readonly _currentUser = signal<UserInfo | null>(this.loadUser());

  readonly currentUser = this._currentUser.asReadonly();

  getAccessToken(): string | null {
    return this.tokenService.get();
  }

  isAuthenticated(): boolean {
    return this.tokenService.has() && this._currentUser() !== null;
  }

  login(payload: LoginRequest): Observable<LoginResponse> {
    return this.http.post<LoginResponse>(
      `${environment.apiUrl}/api/auth/login`,
      payload,
      { withCredentials: true }
    );
  }

  /**
   * Termine la connexion apres validation MFA (challenge).
   * Le backend emet access + refresh ; le refresh est pose en cookie HttpOnly.
   */
  completeLogin(res: LoginResponse): void {
    if (res.accessToken) {
      this.tokenService.set(res.accessToken);
    }
    if (res.user) {
      this._currentUser.set(res.user);
      localStorage.setItem(environment.userKey, JSON.stringify(res.user));
    }
  }

  refresh(): Observable<RefreshResponse> {
    return this.http.post<RefreshResponse>(
      `${environment.apiUrl}/api/auth/refresh`,
      {},
      { withCredentials: true }
    ).pipe(tap(res => this.tokenService.set(res.accessToken)));
  }

  logout(): void {
    this.tokenService.clear();
    this._currentUser.set(null);
    localStorage.removeItem(environment.userKey);
    // Le cookie refresh est invalide cote serveur via /api/auth/logout (a venir L6)
    this.router.navigate(['/login']);
  }

  private loadUser(): UserInfo | null {
    const raw = localStorage.getItem(environment.userKey);
    if (!raw) return null;
    try { return JSON.parse(raw) as UserInfo; } catch { return null; }
  }
}

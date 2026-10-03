import { Injectable, inject } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Router } from '@angular/router';
import { BehaviorSubject, Observable, tap } from 'rxjs';
import { environment } from '../../../environments/environment';
import { LoginRequest, LoginResponse, RefreshResponse, UserInfo } from '../models/login.model';

@Injectable({ providedIn: 'root' })
export class AuthService {

  private readonly http = inject(HttpClient);
  private readonly router = inject(Router);

  private readonly currentUser$ = new BehaviorSubject<UserInfo | null>(this.loadUser());

  get user$(): Observable<UserInfo | null> {
    return this.currentUser$.asObservable();
  }

  get currentUser(): UserInfo | null {
    return this.currentUser$.value;
  }

  get accessToken(): string | null {
    return localStorage.getItem(environment.tokenKey);
  }

  get refreshToken(): string | null {
    return localStorage.getItem(environment.refreshKey);
  }

  isAuthenticated(): boolean {
    return !!this.accessToken && !!this.currentUser;
  }

  login(payload: LoginRequest): Observable<LoginResponse> {
    return this.http.post<LoginResponse>(`${environment.apiUrl}/api/auth/login`, payload)
      .pipe(tap(res => this.storeSession(res)));
  }

  refresh(): Observable<RefreshResponse> {
    const refreshToken = this.refreshToken;
    const tenantCode = this.currentUser?.tenantCode;
    return this.http.post<RefreshResponse>(
      `${environment.apiUrl}/api/auth/refresh`,
      { refreshToken },
      tenantCode ? { headers: { 'X-Tenant-Code': tenantCode } } : {}
    ).pipe(tap(res => {
      localStorage.setItem(environment.tokenKey, res.accessToken);
    }));
  }

  logout(): void {
    localStorage.removeItem(environment.tokenKey);
    localStorage.removeItem(environment.refreshKey);
    localStorage.removeItem(environment.userKey);
    this.currentUser$.next(null);
    this.router.navigate(['/login']);
  }

  private storeSession(res: LoginResponse): void {
    localStorage.setItem(environment.tokenKey, res.accessToken);
    localStorage.setItem(environment.refreshKey, res.refreshToken);
    localStorage.setItem(environment.userKey, JSON.stringify(res.user));
    this.currentUser$.next(res.user);
  }

  private loadUser(): UserInfo | null {
    const raw = localStorage.getItem(environment.userKey);
    if (!raw) return null;
    try { return JSON.parse(raw) as UserInfo; } catch { return null; }
  }
}

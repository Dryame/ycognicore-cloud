import { Routes } from '@angular/router';
import { authGuard } from './core/auth/auth.guard';
import { roleGuard } from './core/auth/role.guard';

export const routes: Routes = [
  {
    path: 'login',
    loadComponent: () => import('./layout/auth-layout/auth-layout.component').then(m => m.AuthLayoutComponent),
    children: [
      { path: '', loadComponent: () => import('./features/auth/login/login.component').then(m => m.LoginComponent) },
      { path: 'mfa', loadComponent: () => import('./features/auth/mfa-challenge/mfa-challenge.component').then(m => m.MfaChallengeComponent) },
    ],
  },
  {
    path: 'superadmin',
    canActivate: [authGuard, roleGuard],
    data: { roles: ['SUPERADMIN'] },
    loadComponent: () => import('./layout/main-layout/main-layout.component').then(m => m.MainLayoutComponent),
    children: [
      { path: '', loadComponent: () => import('./features/dashboard/dashboard.component').then(m => m.DashboardComponent) },
    ],
  },
  {
    path: 'admin',
    canActivate: [authGuard, roleGuard],
    data: { roles: ['ADMIN'] },
    loadComponent: () => import('./layout/main-layout/main-layout.component').then(m => m.MainLayoutComponent),
    children: [
      { path: '', loadComponent: () => import('./features/dashboard/dashboard.component').then(m => m.DashboardComponent) },
    ],
  },
  {
    path: 'employee',
    canActivate: [authGuard, roleGuard],
    data: { roles: ['INTERNE'] },
    loadComponent: () => import('./layout/main-layout/main-layout.component').then(m => m.MainLayoutComponent),
    children: [
      { path: '', loadComponent: () => import('./features/dashboard/dashboard.component').then(m => m.DashboardComponent) },
    ],
  },
  {
    path: 'portal',
    canActivate: [authGuard, roleGuard],
    data: { roles: ['EXTERNE'] },
    loadComponent: () => import('./layout/main-layout/main-layout.component').then(m => m.MainLayoutComponent),
    children: [
      { path: '', loadComponent: () => import('./features/dashboard/dashboard.component').then(m => m.DashboardComponent) },
    ],
  },
  {
    path: 'confidentialite',
    loadComponent: () => import('./features/confidentialite/confidentialite.component')
      .then(m => m.ConfidentialiteComponent),
  },
  {
    path: 'console-securite',
    canActivate: [authGuard],
    loadComponent: () => import('./features/console-securite/console-securite.component')
      .then(m => m.ConsoleSecuriteComponent),
  },
  {
    path: 'plateforme/securite',
    canActivate: [authGuard, roleGuard],
    data: { roles: ['SUPERADMIN'] },
    loadComponent: () => import('./features/platform/platform.component')
      .then(m => m.PlatformComponent),
  },
  { path: '', redirectTo: '/login', pathMatch: 'full' },
  { path: '**', redirectTo: '/login' },
];

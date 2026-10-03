import { Component, inject } from '@angular/core';
import { RouterOutlet, RouterLink } from '@angular/router';
import { AuthService } from '../../core/auth/auth.service';

@Component({
  selector: 'app-main-layout',
  standalone: true,
  imports: [RouterOutlet],
  template: `
    <div class="layout">
      <header class="layout-header">
        <span class="brand">yCogniCore Cloud</span>
        <span class="user-info">
          {{ auth.currentUser?.email }}
          <span class="badge">{{ auth.currentUser?.userType }}</span>
          @if (auth.currentUser?.tenantCode) {
            <span class="tenant">[{{ auth.currentUser?.tenantCode }}]</span>
          }
        </span>
        <button (click)="auth.logout()">Deconnexion</button>
      </header>
      <main class="layout-main">
        <router-outlet></router-outlet>
      </main>
    </div>
  `,
  styles: [`
    .layout { display: flex; flex-direction: column; height: 100vh; }
    .layout-header { display: flex; align-items: center; gap: 1rem; padding: 0.75rem 1rem; background: #1e3a8a; color: white; }
    .brand { font-weight: bold; font-size: 1.1rem; }
    .user-info { margin-left: auto; display: flex; align-items: center; gap: 0.5rem; font-size: 0.9rem; }
    .badge { background: #f59e0b; color: #1e3a8a; padding: 0.15rem 0.5rem; border-radius: 4px; font-size: 0.75rem; font-weight: bold; }
    .tenant { opacity: 0.85; }
    button { background: white; color: #1e3a8a; border: none; padding: 0.4rem 0.8rem; border-radius: 4px; cursor: pointer; font-weight: 500; }
    button:hover { background: #e0e7ff; }
    .layout-main { flex: 1; padding: 1.5rem; overflow-y: auto; background: #f8fafc; }
  `],
})
export class MainLayoutComponent {
  readonly auth = inject(AuthService);
}

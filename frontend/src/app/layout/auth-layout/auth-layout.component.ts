import { Component } from '@angular/core';
import { RouterOutlet } from '@angular/router';

@Component({
  selector: 'app-auth-layout',
  standalone: true,
  imports: [RouterOutlet],
  template: `
    <div class="auth-wrapper">
      <div class="auth-card">
        <h1 class="auth-title">yCogniCore Cloud</h1>
        <router-outlet></router-outlet>
      </div>
    </div>
  `,
  styles: [`
    .auth-wrapper { display: flex; align-items: center; justify-content: center; min-height: 100vh; background: linear-gradient(135deg, #1e3a8a 0%, #3b82f6 100%); }
    .auth-card { background: white; padding: 2.5rem; border-radius: 12px; box-shadow: 0 10px 40px rgba(0,0,0,0.2); width: 100%; max-width: 420px; }
    .auth-title { text-align: center; color: #1e3a8a; margin: 0 0 1.5rem; font-size: 1.5rem; }
  `],
})
export class AuthLayoutComponent {}

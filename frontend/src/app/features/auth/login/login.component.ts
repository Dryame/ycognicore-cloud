import { Component, inject, signal } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { Router } from '@angular/router';
import { AuthService } from '../../../core/auth/auth.service';

@Component({
  selector: 'app-login',
  standalone: true,
  imports: [FormsModule],
  template: `
    <form (ngSubmit)="onSubmit()" #f="ngForm" class="login-form">
      <div class="field">
        <label for="email">Email</label>
        <input id="email" type="email" name="email" [(ngModel)]="email"
               required autocomplete="email" placeholder="votre@email.bf" />
      </div>

      <div class="field">
        <label for="password">Mot de passe</label>
        <input id="password" type="password" name="password" [(ngModel)]="password"
               required autocomplete="current-password" placeholder="********" />
      </div>

      <div class="field">
        <label for="tenantCode">Code tenant (laisser vide pour Superadmin)</label>
        <input id="tenantCode" type="text" name="tenantCode" [(ngModel)]="tenantCode"
               placeholder="DEMO001" />
      </div>

      @if (errorMessage()) {
        <div class="error">{{ errorMessage() }}</div>
      }

      <button type="submit" [disabled]="!f.valid || loading()">
        {{ loading() ? 'Connexion...' : 'Se connecter' }}
      </button>
    </form>
  `,
  styles: [`
    .login-form { display: flex; flex-direction: column; gap: 1rem; }
    .field { display: flex; flex-direction: column; gap: 0.35rem; }
    .field label { font-size: 0.85rem; color: #334155; font-weight: 500; }
    .field input { padding: 0.65rem 0.85rem; border: 1px solid #cbd5e1; border-radius: 6px; font-size: 0.95rem; }
    .field input:focus { outline: none; border-color: #3b82f6; box-shadow: 0 0 0 3px rgba(59,130,246,0.15); }
    .error { color: #dc2626; font-size: 0.85rem; padding: 0.5rem; background: #fee2e2; border-radius: 4px; }
    button { padding: 0.75rem; background: #1e3a8a; color: white; border: none; border-radius: 6px; font-size: 1rem; font-weight: 500; cursor: pointer; }
    button:hover:not(:disabled) { background: #1e40af; }
    button:disabled { opacity: 0.6; cursor: not-allowed; }
  `],
})
export class LoginComponent {
  private readonly auth = inject(AuthService);
  private readonly router = inject(Router);

  email = '';
  password = '';
  tenantCode = '';

  readonly loading = signal(false);
  readonly errorMessage = signal<string | null>(null);

  onSubmit(): void {
    this.loading.set(true);
    this.errorMessage.set(null);

    const payload = {
      email: this.email,
      password: this.password,
      tenantCode: this.tenantCode?.trim() || null,
    };

    this.auth.login(payload).subscribe({
      next: (res) => {
        this.loading.set(false);
        this.router.navigate([res.user.redirectUrl || '/']);
      },
      error: (err) => {
        this.loading.set(false);
        const msg = err?.error?.error || err?.error?.message || err?.message || 'Erreur de connexion';
        this.errorMessage.set(msg);
      },
    });
  }
}

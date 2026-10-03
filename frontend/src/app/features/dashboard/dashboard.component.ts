import { Component, inject } from '@angular/core';
import { AuthService } from '../../core/auth/auth.service';

@Component({
  selector: 'app-dashboard',
  standalone: true,
  template: `
    <div class="dashboard">
      <h2>Tableau de bord</h2>
      <p>Bienvenue <strong>{{ auth.currentUser?.email }}</strong></p>
      <div class="info-grid">
        <div class="info-card">
          <label>Type de profil</label>
          <span>{{ auth.currentUser?.userType }}</span>
        </div>
        @if (auth.currentUser?.tenantCode) {
          <div class="info-card">
            <label>Tenant</label>
            <span>{{ auth.currentUser?.tenantCode }}</span>
          </div>
        }
      </div>
      <p class="placeholder">Le tableau de bord complet sera implemente en Sprint H3 (modules metier).</p>
    </div>
  `,
  styles: [`
    .dashboard h2 { color: #1e3a8a; margin-top: 0; }
    .info-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 1rem; margin: 1.5rem 0; }
    .info-card { background: white; padding: 1rem; border-radius: 8px; box-shadow: 0 2px 8px rgba(0,0,0,0.05); }
    .info-card label { display: block; font-size: 0.75rem; color: #64748b; text-transform: uppercase; margin-bottom: 0.5rem; }
    .info-card span { font-size: 1.25rem; font-weight: bold; color: #1e3a8a; }
    .placeholder { color: #64748b; font-style: italic; margin-top: 2rem; }
  `],
})
export class DashboardComponent {
  readonly auth = inject(AuthService);
}

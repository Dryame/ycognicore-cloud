import { Component, ChangeDetectionStrategy } from '@angular/core';
import { RouterOutlet } from '@angular/router';

/**
 * Layout d'authentification — split-screen, palette marque.
 * Gauche : branding (vert profond + logo).
 * Droite : formulaire (blanc, lisibilité maximale).
 */
@Component({
  selector: 'app-auth-layout',
  standalone: true,
  imports: [RouterOutlet],
  template: `
    <div class="auth-shell">
      <!-- Panneau gauche — branding -->
      <aside class="auth-brand" aria-label="yCogniCore Cloud">
        <div class="brand-inner">
          <header class="brand-header">
            <div class="brand-logo-card">
              <img
                src="assets/brand/logo-ycognicore.svg"
                alt="yCogniCore Cloud"
                class="brand-logo-img" />
            </div>
          </header>

          <div class="brand-content">
            <span class="brand-accent" aria-hidden="true"></span>
            <h1 class="brand-title">
              La plateforme ERP<br />
              qui pense avec vous.
            </h1>
            <p class="brand-subtitle">
              Conçue pour les entreprises exigeantes d'Afrique de l'Ouest.
            </p>
          </div>

          <footer class="brand-footer">
            <span>v3.0</span>
            <span class="brand-sep" aria-hidden="true"></span>
            <span>Burkina Faso</span>
            <span class="brand-sep" aria-hidden="true"></span>
            <span>© 2026</span>
          </footer>
        </div>
      </aside>

      <!-- Panneau droit — formulaire -->
      <main class="auth-panel" role="main">
        <div class="auth-panel-inner">
          <router-outlet></router-outlet>
        </div>
      </main>
    </div>
  `,
  styleUrls: ['./auth-layout.component.scss'],
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class AuthLayoutComponent {}

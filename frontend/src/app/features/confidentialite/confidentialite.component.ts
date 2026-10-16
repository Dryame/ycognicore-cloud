import { Component, ChangeDetectionStrategy } from '@angular/core';
import { CommonModule } from '@angular/common';

/**
 * Page Confidentialite (F9, P-02).
 * Informe l'utilisateur sur la collecte d'IP et la localisation approximative.
 */
@Component({
  selector: 'app-confidentialite',
  standalone: true,
  imports: [CommonModule],
  templateUrl: './confidentialite.component.html',
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class ConfidentialiteComponent {
  readonly derniereMaj = '16 octobre 2026';
  readonly dureeConservation = '30 jours';
  readonly referenceLegale = 'Loi n° 001-2021/AN du 30 mars 2021 (Burkina Faso)';
}

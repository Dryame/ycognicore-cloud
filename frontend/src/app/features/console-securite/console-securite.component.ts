import { Component, ChangeDetectionStrategy, inject, signal, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { ConsoleApiService } from '../../core/http/console-api.service';
import { SessionRow, DeviceRow, EventRow } from '../../core/models/console.model';

/**
 * Console de securite du tenant (T3.13).
 * Ref. : exigence 3.3, ADR-038.
 */
@Component({
  selector: 'app-console-securite',
  standalone: true,
  imports: [CommonModule, FormsModule],
  templateUrl: './console-securite.component.html',
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class ConsoleSecuriteComponent implements OnInit {
  private readonly api = inject(ConsoleApiService);

  readonly loading = signal(false);
  readonly errorMessage = signal<string | null>(null);

  readonly sessions = signal<SessionRow[]>([]);
  readonly devices = signal<DeviceRow[]>([]);
  readonly events = signal<EventRow[]>([]);

  readonly filtreGravite = signal<string>('');
  readonly filtreStatut = signal<string>('');

  ngOnInit(): void {
    this.reload();
  }

  reload(): void {
    this.loading.set(true);
    this.errorMessage.set(null);

    this.api.listSessions().subscribe({
      next: (r) => this.sessions.set(r),
      error: (e) => this.errorMessage.set(e?.error?.error || 'Erreur de chargement'),
    });
    this.api.listDevices().subscribe({ next: (r) => this.devices.set(r) });
    this.api.listEvents(this.filtreGravite() || undefined,
                        this.filtreStatut() || undefined)
      .subscribe({ next: (r) => this.events.set(r) });

    setTimeout(() => this.loading.set(false), 300);
  }

  revokeSession(id: string): void {
    if (!confirm('Révoquer cette session ?')) return;
    this.api.revokeSession(id).subscribe({ next: () => this.reload() });
  }

  blockDevice(id: string): void {
    if (!confirm('Bloquer cet appareil ? Toutes ses sessions tomberont.')) return;
    this.api.blockDevice(id).subscribe({ next: () => this.reload() });
  }

  unblockDevice(id: string): void {
    this.api.unblockDevice(id).subscribe({ next: () => this.reload() });
  }

  appliquerFiltres(): void {
    this.api.listEvents(this.filtreGravite() || undefined,
                        this.filtreStatut() || undefined)
      .subscribe({ next: (r) => this.events.set(r) });
  }
}

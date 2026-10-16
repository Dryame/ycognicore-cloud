import { Component, ChangeDetectionStrategy, inject, signal, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { ConsoleApiService } from '../../core/http/console-api.service';
import { AggregatedEvent } from '../../core/models/console.model';

/**
 * Vue plateforme Superadmin (T3.14).
 * Agrégée, sans donnée métier. Ref. : exigence 3.3.
 */
@Component({
  selector: 'app-platform',
  standalone: true,
  imports: [CommonModule, FormsModule],
  templateUrl: './platform.component.html',
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class PlatformComponent implements OnInit {
  private readonly api = inject(ConsoleApiService);

  readonly events = signal<AggregatedEvent[]>([]);
  readonly filtreGravite = signal<string>('');
  readonly filtreTenant = signal<string>('');

  ngOnInit(): void { this.reload(); }

  reload(): void {
    this.api.listAggregatedEvents(
      this.filtreGravite() || undefined,
      this.filtreTenant() || undefined
    ).subscribe({ next: (r) => this.events.set(r) });
  }
}

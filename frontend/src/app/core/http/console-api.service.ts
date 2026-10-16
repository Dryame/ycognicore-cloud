import { Injectable, inject } from '@angular/core';
import { HttpClient, HttpParams } from '@angular/common/http';
import { Observable } from 'rxjs';
import { environment } from '../../../environments/environment';
import { SessionRow, DeviceRow, EventRow, AggregatedEvent } from '../models/console.model';

/**
 * API de la console de securite (tenant) et de la vue plateforme.
 * Ref. : L6, T3.13, T3.14.
 */
@Injectable({ providedIn: 'root' })
export class ConsoleApiService {
  private readonly http = inject(HttpClient);
  private readonly base = environment.apiUrl;

  // ---- Console tenant ----

  listSessions(userId?: string): Observable<SessionRow[]> {
    let params = new HttpParams();
    if (userId) params = params.set('userId', userId);
    return this.http.get<SessionRow[]>(
      `${this.base}/api/console-securite/sessions`, { params });
  }

  revokeSession(sessionId: string): Observable<unknown> {
    return this.http.post(
      `${this.base}/api/console-securite/sessions/${sessionId}/revoke`, {});
  }

  listDevices(userId?: string): Observable<DeviceRow[]> {
    let params = new HttpParams();
    if (userId) params = params.set('userId', userId);
    return this.http.get<DeviceRow[]>(
      `${this.base}/api/console-securite/appareils`, { params });
  }

  blockDevice(deviceId: string): Observable<unknown> {
    return this.http.post(
      `${this.base}/api/console-securite/appareils/${deviceId}/block`, {});
  }

  unblockDevice(deviceId: string): Observable<unknown> {
    return this.http.post(
      `${this.base}/api/console-securite/appareils/${deviceId}/unblock`, {});
  }

  listEvents(gravite?: string, statut?: string): Observable<EventRow[]> {
    let params = new HttpParams();
    if (gravite) params = params.set('gravite', gravite);
    if (statut) params = params.set('statut', statut);
    return this.http.get<EventRow[]>(
      `${this.base}/api/console-securite/evenements`, { params });
  }

  // ---- Vue plateforme Superadmin ----

  listAggregatedEvents(gravite?: string, tenant?: string): Observable<AggregatedEvent[]> {
    let params = new HttpParams();
    if (gravite) params = params.set('gravite', gravite);
    if (tenant) params = params.set('tenant', tenant);
    return this.http.get<AggregatedEvent[]>(
      `${this.base}/api/platform/evenements`, { params });
  }
}

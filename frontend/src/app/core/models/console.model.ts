export interface SessionRow {
  id: string;
  userId: string;
  appareilId: string | null;
  ip: string | null;
  userAgent: string | null;
  dateOuverture: string;
  dateDerniereActivite: string;
  dateExpiration: string;
  statut: 'ACTIVE' | 'EXPIREE' | 'REVOQUEE';
  motifFermeture: string | null;
}

export interface DeviceRow {
  id: string;
  userId: string;
  navigateur: string | null;
  empreinte: string;
  statut: 'AUTORISE' | 'BLOQUE' | 'SUPPRIME';
  premiereVue: string;
  derniereVue: string;
}

export interface EventRow {
  id: string;
  type: string;
  gravite: 'INFO' | 'WARN' | 'ERROR' | 'CRITIQUE';
  userId: string | null;
  sessionId: string | null;
  appareilId: string | null;
  ip: string | null;
  pays: string | null;
  ville: string | null;
  statutTraitement: 'NOUVEAU' | 'EN_COURS' | 'TRAITE' | 'IGNORE';
  dateCreation: string;
}

export interface AggregatedEvent {
  id: string;
  tenantId: string;
  tenantDbName: string;
  type: string;
  gravite: string;
  dateEvenement: string;
  traite: boolean;
  dateCreation: string;
}

export type UserType = 'SUPERADMIN' | 'ADMIN' | 'INTERNE' | 'EXTERNE';

export interface CurrentUser {
  userId: string;
  email: string;
  userType: UserType;
  tenantCode: string | null;
  redirectUrl: string;
}

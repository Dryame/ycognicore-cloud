export interface LoginRequest {
  email: string;
  password: string;
  tenantCode?: string | null;
}

export interface UserInfo {
  userId: string;
  email: string;
  userType: 'SUPERADMIN' | 'ADMIN' | 'INTERNE' | 'EXTERNE';
  tenantCode: string | null;
  redirectUrl: string;
}

export interface LoginResponse {
  accessToken: string;
  refreshToken: string;
  tokenType: string;
  expiresInSeconds: number;
  user: UserInfo;
}

export interface RefreshResponse {
  accessToken: string;
  tokenType: string;
  expiresInSeconds: number;
}

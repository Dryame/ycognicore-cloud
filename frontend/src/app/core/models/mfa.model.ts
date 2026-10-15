export interface MfaChallengeVerifyRequest {
  challengeToken: string;
  code: string;
}

export interface MfaVerifyRequest {
  secret: string;
  code: number;
}

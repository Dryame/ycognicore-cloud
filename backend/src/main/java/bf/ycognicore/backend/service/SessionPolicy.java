package bf.ycognicore.backend.service;

/**
 * Politique de sessions — valeurs P-01 (validées encadreur 15/10/2026).
 * Ref. : P-01, F4, T3.3.
 */
public record SessionPolicy(
    int sessionsMax,
    int inactiviteMinutes,
    int dureeAbsolueHeures,
    int accessTokenMinutes,
    int refreshTokenJours,
    int verrouillageSeuil,
    int verrouillageDureeMinutes
) {
    public static final SessionPolicy DEFAUT = new SessionPolicy(
        5, 30, 12, 30, 7, 5, 15);

    public static final int SESSIONS_MAX_MIN = 1;
    public static final int SESSIONS_MAX_MAX = 20;
    public static final int INACTIVITE_MIN = 5;
    public static final int INACTIVITE_MAX = 480;
    public static final int DUREE_ABSOLUE_MIN = 1;
    public static final int DUREE_ABSOLUE_MAX = 168;
    public static final int ACCESS_MIN = 5;
    public static final int ACCESS_MAX = 60;
    public static final int REFRESH_MIN = 1;
    public static final int REFRESH_MAX = 30;
    public static final int VERROU_MIN = 5;
    public static final int VERROU_MAX = 60;

    /** Applique les bornes plateforme (min/max) sur des valeurs tenant. */
    public SessionPolicy clamp() {
        return new SessionPolicy(
            clamp(sessionsMax, SESSIONS_MAX_MIN, SESSIONS_MAX_MAX),
            clamp(inactiviteMinutes, INACTIVITE_MIN, INACTIVITE_MAX),
            clamp(dureeAbsolueHeures, DUREE_ABSOLUE_MIN, DUREE_ABSOLUE_MAX),
            clamp(accessTokenMinutes, ACCESS_MIN, ACCESS_MAX),
            clamp(refreshTokenJours, REFRESH_MIN, REFRESH_MAX),
            verrouillageSeuil,
            clamp(verrouillageDureeMinutes, VERROU_MIN, VERROU_MAX)
        );
    }

    private static int clamp(int v, int min, int max) {
        return Math.max(min, Math.min(max, v));
    }
}

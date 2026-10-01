package bf.ycognicore.backend.entity.controlplane.ids;

import java.io.Serializable;
import java.time.OffsetDateTime;
import java.util.Objects;

/**
 * Cle composite de superadmin_login_attempts (id, timestamp).
 */
public class SuperadminLoginAttemptId implements Serializable {

    private Long id;
    private OffsetDateTime timestamp;

    public SuperadminLoginAttemptId() {}

    public Long getId() { return id; }
    public void setId(Long v) { this.id = v; }
    public OffsetDateTime getTimestamp() { return timestamp; }
    public void setTimestamp(OffsetDateTime v) { this.timestamp = v; }

    @Override public boolean equals(Object o) {
        if (this == o) return true;
        if (!(o instanceof SuperadminLoginAttemptId that)) return false;
        return Objects.equals(id, that.id) && Objects.equals(timestamp, that.timestamp);
    }
    @Override public int hashCode() { return Objects.hash(id, timestamp); }
}

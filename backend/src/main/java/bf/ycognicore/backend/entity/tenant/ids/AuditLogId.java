package bf.ycognicore.backend.entity.tenant.ids;
import java.io.Serializable;
import java.time.OffsetDateTime;
import java.util.Objects;
public class AuditLogId implements Serializable {
    private Long id;
    private OffsetDateTime timestamp;
    public AuditLogId() {}
    public Long getId() { return id; }
    public void setId(Long v) { this.id = v; }
    public OffsetDateTime getTimestamp() { return timestamp; }
    public void setTimestamp(OffsetDateTime v) { this.timestamp = v; }
    @Override public boolean equals(Object o) {
        if (this == o) return true;
        if (!(o instanceof AuditLogId that)) return false;
        return Objects.equals(id, that.id) && Objects.equals(timestamp, that.timestamp);
    }
    @Override public int hashCode() { return Objects.hash(id, timestamp); }
}

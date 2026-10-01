package bf.ycognicore.backend.entity.tenant.ids;
import java.io.Serializable;
import java.time.OffsetDateTime;
import java.util.Objects;
public class LoginAttemptId implements Serializable {
    private Long id;
    private OffsetDateTime timestamp;
    public LoginAttemptId() {}
    public Long getId() { return id; }
    public void setId(Long v) { this.id = v; }
    public OffsetDateTime getTimestamp() { return timestamp; }
    public void setTimestamp(OffsetDateTime v) { this.timestamp = v; }
    @Override public boolean equals(Object o) {
        if (this == o) return true;
        if (!(o instanceof LoginAttemptId that)) return false;
        return Objects.equals(id, that.id) && Objects.equals(timestamp, that.timestamp);
    }
    @Override public int hashCode() { return Objects.hash(id, timestamp); }
}

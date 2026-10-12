package bf.ycognicore.backend.migration;

import java.util.ArrayList;
import java.util.List;

public class MigrationReport {

    private final List<String> successes = new ArrayList<>();
    private final List<Failure> failures = new ArrayList<>();

    public void addSuccess(String tenant) { successes.add(tenant); }
    public void addFailure(String tenant, String reason) { failures.add(new Failure(tenant, reason)); }

    public int successCount() { return successes.size(); }
    public int failureCount() { return failures.size(); }
    public List<String> successes() { return List.copyOf(successes); }
    public List<Failure> failures() { return List.copyOf(failures); }

    public String summary() {
        return String.format("%d réussite(s), %d échec(s)", successCount(), failureCount());
    }

    public record Failure(String tenant, String reason) {}
}

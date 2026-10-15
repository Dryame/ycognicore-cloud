package bf.ycognicore.backend.architecture;

import com.tngtech.archunit.core.domain.JavaClasses;
import com.tngtech.archunit.core.importer.ClassFileImporter;
import com.tngtech.archunit.core.importer.ImportOption;
import com.tngtech.archunit.lang.ArchRule;
import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.Test;

import static com.tngtech.archunit.lang.syntax.ArchRuleDefinition.noClasses;

class AuditArchitectureTest {

    private static JavaClasses classes;

    @BeforeAll
    static void loadClasses() {
        classes = new ClassFileImporter()
            .withImportOption(ImportOption.Predefined.DO_NOT_INCLUDE_TESTS)
            .importPackages("bf.ycognicore.backend");
    }

    @Test
    void audit_log_accessed_only_by_audit_module() {
        ArchRule rule = noClasses()
            .that().resideOutsideOfPackage("bf.ycognicore.backend.audit..")
            .and().resideOutsideOfPackage("bf.ycognicore.backend.service..")
            .and().resideOutsideOfPackage("bf.ycognicore.backend.repository.tenant..")
            .and().resideOutsideOfPackage("bf.ycognicore.backend.entity.tenant..")
            .should().dependOnClassesThat()
            .haveFullyQualifiedName("bf.ycognicore.backend.entity.tenant.AuditLog")
            .because("Toute ecriture dans audit_log doit passer par CentralAuditService");

        rule.check(classes);
    }

    @Test
    void central_audit_service_is_the_only_public_audit_entry_point() {
        ArchRule rule = noClasses()
            .that().resideOutsideOfPackage("bf.ycognicore.backend.audit..")
            .and().resideOutsideOfPackage("bf.ycognicore.backend.service..")
            .should().dependOnClassesThat()
            .haveFullyQualifiedName("bf.ycognicore.backend.service.AuditService")
            .because("AuditService est un detail d'implementation - CentralAuditService est le point d'entree");

        rule.check(classes);
    }
}

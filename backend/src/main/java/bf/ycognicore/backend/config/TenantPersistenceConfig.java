package bf.ycognicore.backend.config;

import bf.ycognicore.backend.multitenant.MultiTenantConnectionProviderImpl;
import bf.ycognicore.backend.multitenant.TenantIdentifierResolver;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.data.jpa.repository.config.EnableJpaRepositories;
import org.springframework.orm.jpa.JpaTransactionManager;
import org.springframework.orm.jpa.LocalContainerEntityManagerFactoryBean;
import org.springframework.orm.jpa.vendor.HibernateJpaVendorAdapter;
import org.springframework.transaction.PlatformTransactionManager;

import java.util.HashMap;
import java.util.Map;

/**
 * Persistence unit TENANT - routage dynamique via Hibernate MT SPI.
 * Mode DATABASE (une base PostgreSQL par tenant). ADR-006.
 *
 * Note : les cles Hibernate sont passees en String litteral (et non via
 * AvailableSettings) pour resister aux reorganisations d'API Hibernate 7.
 */
@Configuration
@EnableJpaRepositories(
        basePackages = "bf.ycognicore.backend.repository.tenant",
        entityManagerFactoryRef = "tenantEntityManagerFactory",
        transactionManagerRef = "tenantTransactionManager"
)
public class TenantPersistenceConfig {

    @Bean(name = "tenantEntityManagerFactory")
    public LocalContainerEntityManagerFactoryBean tenantEntityManagerFactory(
            MultiTenantConnectionProviderImpl connectionProvider,
            TenantIdentifierResolver tenantIdentifierResolver) {

        LocalContainerEntityManagerFactoryBean emf = new LocalContainerEntityManagerFactoryBean();
        emf.setDataSource(connectionProvider);
        emf.setPackagesToScan("bf.ycognicore.backend.entity.tenant");
        emf.setPersistenceUnitName("tenant");

        HibernateJpaVendorAdapter adapter = new HibernateJpaVendorAdapter();
        adapter.setShowSql(true);
        adapter.setGenerateDdl(false);
        emf.setJpaVendorAdapter(adapter);

        Map<String, Object> props = new HashMap<>();
        props.put("hibernate.dialect", "org.hibernate.dialect.PostgreSQLDialect");
        props.put("hibernate.multiTenancy", "DATABASE");
        props.put("hibernate.multiTenantConnectionProvider", connectionProvider);
        props.put("hibernate.tenantIdentifierResolver", tenantIdentifierResolver);
        props.put("hibernate.hbm2ddl.auto", "none");
        props.put("hibernate.format_sql", "true");
        props.put("hibernate.jdbc.time_zone", "UTC");
        emf.setJpaPropertyMap(props);

        return emf;
    }

    @Bean(name = "tenantTransactionManager")
    public PlatformTransactionManager tenantTransactionManager(
            @Qualifier("tenantEntityManagerFactory")
            LocalContainerEntityManagerFactoryBean emf) {
        return new JpaTransactionManager(emf.getObject());
    }
}

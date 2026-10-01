package bf.ycognicore.backend.config;

import com.zaxxer.hikari.HikariConfig;
import com.zaxxer.hikari.HikariDataSource;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Primary;
import org.springframework.data.jpa.repository.config.EnableJpaRepositories;
import org.springframework.orm.jpa.JpaTransactionManager;
import org.springframework.orm.jpa.LocalContainerEntityManagerFactoryBean;
import org.springframework.orm.jpa.vendor.HibernateJpaVendorAdapter;
import org.springframework.transaction.PlatformTransactionManager;

import javax.sql.DataSource;
import java.util.HashMap;
import java.util.Map;

/**
 * Persistence unit CONTROL PLANE - ycc_control_plane.
 * Construction manuelle (Spring Boot 4 a deplace les packages
 * DataSourceProperties / EntityManagerFactoryBuilder).
 *
 * Ref. : ADR-006, dictionnaire v1.2 Partie 1
 */
@Configuration
@EnableJpaRepositories(
        basePackages = "bf.ycognicore.backend.repository.controlplane",
        entityManagerFactoryRef = "controlPlaneEntityManagerFactory",
        transactionManagerRef = "controlPlaneTransactionManager"
)
public class ControlPlanePersistenceConfig {

    @Value("${spring.datasource.url}")
    private String url;

    @Value("${spring.datasource.username}")
    private String username;

    @Value("${spring.datasource.password}")
    private String password;

    @Value("${spring.datasource.hikari.pool-name:cp-pool}")
    private String poolName;

    @Value("${spring.datasource.hikari.maximum-pool-size:5}")
    private int maxPoolSize;

    @Value("${spring.datasource.hikari.minimum-idle:1}")
    private int minIdle;

    @Primary
    @Bean(name = "controlPlaneDataSource")
    public DataSource controlPlaneDataSource() {
        HikariConfig hc = new HikariConfig();
        hc.setJdbcUrl(url);
        hc.setUsername(username);
        hc.setPassword(password);
        hc.setPoolName(poolName);
        hc.setMaximumPoolSize(maxPoolSize);
        hc.setMinimumIdle(minIdle);
        return new HikariDataSource(hc);
    }

    @Primary
    @Bean(name = "controlPlaneEntityManagerFactory")
    public LocalContainerEntityManagerFactoryBean controlPlaneEntityManagerFactory(
            @Qualifier("controlPlaneDataSource") DataSource dataSource) {
        LocalContainerEntityManagerFactoryBean emf = new LocalContainerEntityManagerFactoryBean();
        emf.setDataSource(dataSource);
        emf.setPackagesToScan("bf.ycognicore.backend.entity.controlplane");
        emf.setPersistenceUnitName("controlPlane");

        HibernateJpaVendorAdapter adapter = new HibernateJpaVendorAdapter();
        adapter.setShowSql(true);
        adapter.setGenerateDdl(false);
        emf.setJpaVendorAdapter(adapter);

        Map<String, Object> props = new HashMap<>();
        props.put("hibernate.hbm2ddl.auto", "validate");
        props.put("hibernate.format_sql", "true");
        props.put("hibernate.jdbc.time_zone", "UTC");
        emf.setJpaPropertyMap(props);

        return emf;
    }

    @Primary
    @Bean(name = "controlPlaneTransactionManager")
    public PlatformTransactionManager controlPlaneTransactionManager(
            @Qualifier("controlPlaneEntityManagerFactory")
            LocalContainerEntityManagerFactoryBean emf) {
        return new JpaTransactionManager(emf.getObject());
    }
}

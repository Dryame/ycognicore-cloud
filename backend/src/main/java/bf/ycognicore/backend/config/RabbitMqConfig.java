package bf.ycognicore.backend.config;

import org.springframework.amqp.core.*;
import org.springframework.amqp.rabbit.annotation.EnableRabbit;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
@EnableRabbit
public class RabbitMqConfig {

    public static final String EXCHANGE_NAME = "ycc.events";
    public static final String QUEUE_NAME = "ycc.outbox.queue";

    @Bean
    public TopicExchange eventExchange() {
        return new TopicExchange(EXCHANGE_NAME);
    }

    @Bean
    public Queue outboxQueue() {
        return new Queue(QUEUE_NAME, true); // Durable
    }

    @Bean
    public Binding outboxBinding(Queue outboxQueue, TopicExchange eventExchange) {
        return BindingBuilder.bind(outboxQueue).to(eventExchange).with("#");
    }
}

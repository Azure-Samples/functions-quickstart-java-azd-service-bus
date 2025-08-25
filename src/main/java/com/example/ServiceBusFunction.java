package com.example;

import com.microsoft.azure.functions.annotation.*;
import com.microsoft.azure.functions.*;
import java.util.logging.Logger;

/**
 * Azure Functions with Service Bus Trigger.
 */
public class ServiceBusFunction {
    /**
     * This function will be invoked when a message is received on a Service Bus queue.
     * @param message The Service Bus message.
     * @param context The execution context.
     */
    @FunctionName("serviceBusQueueTrigger")
    public void serviceBusQueueTrigger(
        @ServiceBusQueueTrigger(
            name = "message",
            queueName = "%ServiceBusQueueName%",
            connection = "ServiceBusConnection"
        ) String message,
        final ExecutionContext context
    ) {
        Logger logger = context.getLogger();
        logger.info("Java ServiceBus Queue trigger start processing a message: " + message);
        
        try {
            // Sleep for 30 seconds to simulate processing time
            Thread.sleep(30000);
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            logger.warning("Processing was interrupted: " + e.getMessage());
        }
        
        logger.info("Java ServiceBus Queue trigger end processing a message");
    }
}

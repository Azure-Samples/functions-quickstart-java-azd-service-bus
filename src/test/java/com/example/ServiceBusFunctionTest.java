package com.example;

import com.microsoft.azure.functions.*;
import org.mockito.invocation.InvocationOnMock;
import org.mockito.stubbing.Answer;

import java.util.logging.Logger;

import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

/**
 * Unit test for ServiceBusFunction class.
 */
public class ServiceBusFunctionTest {
    /**
     * Unit test for serviceBusQueueTrigger method.
     */
    @Test
    public void testServiceBusQueueTrigger() throws Exception {
        // Setup
        @SuppressWarnings("unchecked")
        final ExecutionContext context = mock(ExecutionContext.class);
        final Logger logger = Logger.getLogger(ServiceBusFunctionTest.class.getName());
        doReturn(logger).when(context).getLogger();

        // Invoke
        final ServiceBusFunction function = new ServiceBusFunction();
        final String message = "test message";
        
        // Test that the function executes without throwing an exception
        assertDoesNotThrow(() -> {
            function.serviceBusQueueTrigger(message, context);
        });
    }

    @Test
    public void testInterruptedProcessingFailsWithoutLoggingCompletion() {
        final ExecutionContext context = mock(ExecutionContext.class);
        final Logger logger = mock(Logger.class);
        doReturn(logger).when(context).getLogger();

        Thread.currentThread().interrupt();
        try {
            final IllegalStateException error = assertThrows(IllegalStateException.class,
                () -> new ServiceBusFunction().serviceBusQueueTrigger("interrupted message", context));

            assertInstanceOf(InterruptedException.class, error.getCause());
            assertTrue(Thread.currentThread().isInterrupted());
            verify(logger, never()).info("Java ServiceBus Queue trigger end processing a message");
        } finally {
            Thread.interrupted();
        }
    }
}

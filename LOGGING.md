# Medoru Logging Guide

This document describes the logging infrastructure and best practices for the Medoru application.

## Overview

Medoru uses structured logging with:
- **Development**: Human-readable console output with metadata
- **Production**: JSON-formatted logs with file rotation
- **Testing**: Minimal output to reduce noise

## Quick Reference

### Using the Logger

```elixir
alias Medoru.Logger, as: AppLogger

# Simple logging
AppLogger.info("User logged in", %{user_id: user.id})
AppLogger.error("Payment failed", %{user_id: user.id, amount: 100})

# With context
AppLogger.with_context(%{request_id: request_id, user_id: user.id}, fn ->
  AppLogger.info("Processing order")
  # ... code ...
  AppLogger.info("Order complete", %{order_id: order.id})
end)

# Exception handling
try do
  risky_operation()
rescue
  e ->
    AppLogger.exception(e, __STACKTRACE__, "Operation failed", %{context: "extra info"})
end

# Audit logs (for security-sensitive operations)
AppLogger.audit("user.login", %{user_id: user.id, ip: "192.168.1.1"})
AppLogger.audit("admin.user_promoted", %{admin_id: admin.id, target_id: user.id})
```

## Configuration

### Development

Logs are output to the console with:
- Debug level and above
- Metadata: request_id, user_id, module, function, line
- Human-readable format

### Test

Logs are output to the console with:
- Warning level and above (to reduce noise)
- Simple format

### Production

Logs are output to:
1. **Console** (for container orchestrators)
2. **File** (`/var/log/medoru/app.log`) with:
   - Info level and above
   - JSON format for parsing
   - Size-based rotation (10MB per file, keep 5 files)

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `LOG_LEVEL` | Minimum log level | `info` |
| `LOG_PATH` | Log file path | `/var/log/medoru/app.log` |

## Request Logging

All HTTP requests are automatically logged with:
- Request ID (for tracing)
- User ID (if authenticated)
- IP address
- Method and path
- Status code
- Duration in milliseconds
- User agent

## Metadata Fields

Common metadata fields used:

| Field | Description | Example |
|-------|-------------|---------|
| `request_id` | Unique request identifier | `"a1b2c3d4"` |
| `user_id` | Authenticated user ID | `"123e4567-..."` |
| `ip` | Client IP address | `"192.168.1.1"` |
| `module` | Source module | `Medoru.Accounts` |
| `function` | Source function | `create_user/1` |
| `action` | Audit action type | `"user.login"` |

## Log Rotation

### Built-in Rotation

The application uses `LoggerFileBackend` which supports:
- Size-based rotation (10MB per file)
- Keeps 5 rotated files

### System Logrotate (Recommended)

For production deployments, use system logrotate:

```bash
# Copy the configuration
sudo cp rel/overlays/logrotate.conf /etc/logrotate.d/medoru
sudo chmod 644 /etc/logrotate.d/medoru

# Create log directory
sudo mkdir -p /var/log/medoru
sudo chown medoru:medoru /var/log/medoru
```

## Best Practices

1. **Use structured metadata** instead of string interpolation:
   ```elixir
   # Good
   AppLogger.info("User action", %{user_id: user.id, action: "delete"})
   
   # Avoid
   AppLogger.info("User #{user.id} performed delete")
   ```

2. **Choose appropriate log levels**:
   - `debug`: Detailed debugging info
   - `info`: Normal operations (user login, requests)
   - `warning`: Recoverable issues (rate limiting, retries)
   - `error`: Failures requiring attention

3. **Use `with_context` for related operations**:
   ```elixir
   AppLogger.with_context(%{job_id: job_id}, fn ->
     # All logs will include job_id
     process_steps()
   end)
   ```

4. **Use audit logs for security events**:
   ```elixir
   AppLogger.audit("user.password_changed", %{user_id: user.id})
   ```

5. **Include relevant context in errors**:
   ```elixir
   AppLogger.error("Database connection failed", %{
     host: db_host,
     retry_count: retries
   })
   ```

## Log Analysis

### Production (JSON)

```bash
# View recent errors
jq 'select(.level == "error")' /var/log/medoru/app.log

# Filter by user
jq 'select(.metadata.user_id == "xxx")' /var/log/medoru/app.log

# Request tracing
jq 'select(.metadata.request_id == "abc123")' /var/log/medoru/app.log
```

### Development

```bash
# Filter by level
mix phx.server 2>&1 | grep "\[error\]"

# Follow logs
mix phx.server 2>&1 | tail -f
```

## Troubleshooting

### Logs not appearing

1. Check log level: `Logger.level()`
2. Verify backend is configured: `Logger.backends()`
3. Check file permissions for `/var/log/medoru`

### Disk space issues

1. Verify logrotate is configured
2. Check rotation settings in `config/prod.exs`
3. Monitor log file sizes: `du -h /var/log/medoru/`

### Performance issues

1. Use async logging (default)
2. Reduce metadata in high-traffic areas
3. Consider sampling for debug logs

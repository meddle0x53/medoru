# Iteration 11: Logging Infrastructure

**Status**: ✅ COMPLETE  
**Date**: 2026-03-08  
**Priority**: Medium

## Overview

Implemented a comprehensive structured logging solution with environment-specific configuration, JSON formatting for production, file rotation, and request logging.

## Changes Made

### 1. Dependencies Added
- `logger_backends` - Modern backend support for Elixir 1.15+
- `logger_file_backend` - File output with rotation
- `logger_json` - JSON formatting for production

### 2. Configuration Files Updated

**config/config.exs**
- Base formatter configuration
- Metadata fields: request_id, user_id, ip, module, function, line

**config/dev.exs**
- Debug level logging
- Human-readable format with metadata

**config/test.exs**
- Warning level to reduce noise
- Unchanged (already appropriate)

**config/prod.exs**
- Info level with JSON formatting
- Console output (for containers)
- File backend configured in Application

### 3. New Files Created

**lib/medoru/logger.ex**
Structured logging interface with:
- `debug/2`, `info/2`, `warning/2`, `error/2` - Level-specific logging
- `log/3` - Dynamic level logging
- `exception/4` - Exception logging with stacktrace
- `with_context/2` - Scoped metadata
- `put_context/1` - Add metadata to current process
- `audit/2` - Security audit logging

**lib/medoru_web/plugs/request_logger.ex**
Request logging plug with:
- Automatic request ID generation
- User ID extraction from session
- IP address tracking
- Duration measurement
- Status-based log levels (error for 5xx, warning for 4xx, info for success)

**lib/medoru/application.ex**
- Runtime configuration of file backend for production
- Environment-aware logging setup

**rel/overlays/logrotate.conf**
- System logrotate configuration for production
- Daily rotation, 30 days retention

**LOGGING.md**
- Comprehensive logging guide
- Usage examples
- Configuration reference
- Best practices

### 4. Router Updated
- Added `RequestLogger` plug to browser pipeline

## Files Modified

```
mix.exs                                    # Added dependencies
config/config.exs                          # Base logger config
config/dev.exs                             # Dev logging config
config/prod.exs                            # Prod logging config
lib/medoru/application.ex                  # Runtime backend setup
lib/medoru_web/router.ex                   # Added RequestLogger plug
```

## Files Created

```
lib/medoru/logger.ex                       # Structured logging API
lib/medoru_web/plugs/request_logger.ex     # Request logging plug
rel/overlays/logrotate.conf                # Logrotate configuration
LOGGING.md                                 # Documentation
```

## Usage Examples

```elixir
alias Medoru.Logger, as: AppLogger

# Simple logging
AppLogger.info("User logged in", %{user_id: user.id})
AppLogger.error("Payment failed", %{user_id: user.id, amount: 100})

# With context
AppLogger.with_context(%{request_id: request_id}, fn ->
  AppLogger.info("Processing")
  process_data()
  AppLogger.info("Complete")
end)

# Exception handling
try do
  risky_operation()
rescue
  e -> AppLogger.exception(e, __STACKTRACE__, "Failed")
end

# Audit logging
AppLogger.audit("user.login", %{user_id: user.id, ip: ip})
```

## Test Results

```
274 tests, 0 failures
```

## Environment Configuration

| Environment | Level | Format | Output |
|-------------|-------|--------|--------|
| Development | debug | Human-readable | Console |
| Test | warning | Simple | Console |
| Production | info | JSON | Console + File |

## Definition of Done

- [x] Logger dependencies added
- [x] Logger configuration per environment
- [x] Custom Medoru.Logger module created
- [x] Request logging plug implemented
- [x] Log rotation configured for production
- [x] JSON formatting in production
- [x] Documentation on logging practices
- [x] Tests passing (274 tests)

## Next Steps

**Iteration 12: Kanji Stroke Animation**
- SVG stroke data for kanji
- Animated stroke order visualization
- Practice drawing mode

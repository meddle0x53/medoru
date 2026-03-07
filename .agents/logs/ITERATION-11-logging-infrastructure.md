# Iteration 11: Logging Infrastructure

**Status**: PLANNED  
**Date**: 2026-03-07  
**Priority**: Medium

## Overview

Replace all `IO.puts/1`, `IO.inspect/1`, and `Logger` default usage with a proper structured logging solution including log rotation, JSON formatting for production, and configurable log levels per environment.

## Current State

Currently using:
- `IO.puts/2` in seeds.exs
- `IO.inspect/1` for debugging
- Default Elixir `Logger` without configuration
- No log rotation
- Logs go to stdout only

## Goals

1. **Structured Logging**
   - JSON logs in production for parsing
   - Human-readable logs in development
   - Consistent log format with timestamps, level, metadata

2. **Log Rotation**
   - Size-based rotation
   - Age-based cleanup (keep last 30 days)
   - Separate files per log level (optional)

3. **Replace IO Usage**
   - Remove all `IO.puts` from production code
   - Keep `IO.puts` only in mix tasks/seeds
   - Replace with proper Logger calls

4. **Configuration**
   - Different log levels per environment
   - Configurable output destinations
   - Metadata inclusion (request_id, user_id, etc.)

## Technical Approach

### Libraries to Consider

| Library | Purpose | Notes |
|---------|---------|-------|
| **LoggerFileBackend** | File backend for Logger | Simple, widely used |
| **LoggerJSON** | JSON formatting | Good for production |
| **RingLogger** | In-memory ring buffer | Good for live debugging |
| **Logstash/Vector** | Log shipping | Future integration |

### Recommended Stack

**Development:**
- Logger with console backend
- Human-readable format
- Debug level

**Production:**
- Logger with file backend
- JSON format
- Info level
- Log rotation via external tool (logrotate) or built-in

## Implementation Tasks

### 1. Add Dependencies

```elixir
# mix.exs
defp deps do
  [
    {:logger_file_backend, "~> 0.0.12"},
    {:logger_json, "~> 5.0"}
  ]
end
```

### 2. Configure Logger

**config/config.exs:**
```elixir
config :logger,
  backends: [:console],
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id, :user_id, :ip]
```

**config/prod.exs:**
```elixir
config :logger,
  backends: [{LoggerFileBackend, :file_log}],
  format: {LoggerJSON.Formatters.BasicLog, :format}

config :logger, :file_log,
  path: "/var/log/medoru/app.log",
  level: :info,
  rotate: %{max_bytes: 10_000_000, keep: 5}
```

### 3. Create Logging Module

**lib/medoru/logger.ex:**
```elixir
defmodule Medoru.Logger do
  @moduledoc """
  Structured logging for Medoru.
  """
  
  require Logger
  
  def info(msg, metadata \\ %{}) do
    Logger.info(msg, metadata: Map.to_list(metadata))
  end
  
  def error(msg, metadata \\ %{}) do
    Logger.error(msg, metadata: Map.to_list(metadata))
  end
  
  def debug(msg, metadata \\ %{}) do
    Logger.debug(msg, metadata: Map.to_list(metadata))
  end
  
  # With request context
  def with_context(context, fun) do
    Logger.metadata(context)
    fun.()
    Logger.metadata(context)
  end
end
```

### 4. Replace IO Usage

**Files to update:**
- `priv/repo/seeds.exs` - Keep IO.puts (seeds are one-off)
- `lib/medoru/release/seeds.ex` - Convert to Logger
- Any `IO.inspect` in production code - Remove or convert to Logger.debug

### 5. Add Request Logging

**lib/medoru_web/plugs/request_logger.ex:**
```elixir
defmodule MedoruWeb.Plugs.RequestLogger do
  @moduledoc """
  Logs request metadata.
  """
  
  def init(opts), do: opts
  
  def call(conn, _opts) do
    start_time = System.monotonic_time()
    
    Logger.metadata(
      request_id: conn.assigns[:request_id],
      user_id: conn.assigns[:current_user]&.id,
      ip: conn.remote_ip |> :inet.ntoa() |> to_string(),
      method: conn.method,
      path: conn.request_path
    )
    
    conn
    |> Plug.Conn.register_before_send(fn conn ->
      duration = System.monotonic_time() - start_time
      
      Medoru.Logger.info("Request completed", %{
        status: conn.status,
        duration_ms: System.convert_time_unit(duration, :native, :millisecond)
      })
      
      conn
    end)
  end
end
```

### 6. Log Rotation Setup

**Option A: Built-in (LoggerFileBackend)**
Already handled by configuration

**Option B: System logrotate**
Create `/etc/logrotate.d/medoru`:
```
/var/log/medoru/*.log {
    daily
    rotate 30
    compress
    delaycompress
    missingok
    notifempty
    create 0644 medoru medoru
    sharedscripts
    postrotate
        systemctl restart medoru
    endscript
}
```

## Files to Modify

```
config/config.exs
config/dev.exs
config/prod.exs
config/test.exs
lib/medoru/logger.ex (new)
lib/medoru_web/plugs/request_logger.ex (new)
lib/medoru/release/seeds.ex
lib/medoru/learning.ex (remove IO.inspect)
# Any other files with IO.inspect
```

## Environment Configuration

### Development
- Console output only
- Debug level
- Human-readable format
- Metadata: module, function, line

### Test
- Console output
- Warning level (reduce noise)
- Simple format

### Production
- File output + optional external shipping
- Info level
- JSON format
- Metadata: request_id, user_id, timestamp
- Rotation: 10MB per file, keep 30 files

## Audit Current IO Usage

```bash
# Find all IO.puts/IO.inspect
grep -r "IO\." lib/ --include="*.ex" | grep -v "File.io"
grep -r "IO\." lib/medoru_web/ --include="*.ex"
```

Expected findings to fix:
- `IO.inspect` in learning.ex (debugging)
- `IO.puts` in release/seeds.ex

## Definition of Done

- [ ] Logger dependencies added
- [ ] Logger configuration per environment
- [ ] Custom Medoru.Logger module created
- [ ] All production `IO.puts` replaced
- [ ] All production `IO.inspect` removed/replaced
- [ ] Request logging plug implemented
- [ ] Log rotation configured for production
- [ ] JSON formatting in production
- [ ] Documentation on logging practices
- [ ] Tests passing

## Benefits

1. **Production Debugging**: Structured logs searchable in log aggregation tools
2. **Performance**: File backend faster than console in production
3. **Reliability**: Log rotation prevents disk filling
4. **Security**: Request metadata for audit trails
5. **Maintainability**: Consistent logging interface

## Next Steps After Completion

**Iteration 12: Kanji Stroke Animation**
- SVG stroke data for kanji
- Animated stroke order visualization
- Practice drawing mode

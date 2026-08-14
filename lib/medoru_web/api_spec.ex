defmodule MedoruWeb.ApiSpec do
  @moduledoc """
  OpenAPI specification for the Medoru public API.
  """

  alias OpenApiSpex.{Components, Info, MediaType, OpenApi, Operation, PathItem, Response, Schema}

  @version "0.1.0"

  defmodule HealthResponse do
    @moduledoc false
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "HealthResponse",
      description: "Simple health check response",
      type: :object,
      properties: %{
        status: %Schema{type: :string, example: "ok"}
      },
      required: [:status],
      example: %{"status" => "ok"}
    })
  end

  defmodule KanjiListItem do
    @moduledoc false
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "KanjiListItem",
      description: "A kanji returned in a list",
      type: :object,
      properties: %{
        character: %Schema{type: :string, example: "日"},
        meanings: %Schema{type: :array, items: %Schema{type: :string}, example: ["sun", "day"]},
        stroke_count: %Schema{type: :integer, example: 4},
        jlpt_level: %Schema{type: :integer, nullable: true, example: 5},
        radicals: %Schema{type: :array, nullable: true, items: %Schema{type: :string}},
        frequency: %Schema{type: :integer, nullable: true},
        school_level: %Schema{type: :integer, nullable: true},
        bg_meanings: %Schema{
          type: :array,
          nullable: true,
          items: %Schema{type: :string},
          description: "Included only when `include=bg_meanings` is requested"
        }
      },
      required: [:character, :meanings, :stroke_count]
    })
  end

  defmodule KanjiDetail do
    @moduledoc false
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "KanjiDetail",
      description: "Detailed kanji response",
      type: :object,
      properties: %{
        character: %Schema{type: :string, example: "日"},
        meanings: %Schema{type: :array, items: %Schema{type: :string}, example: ["sun", "day"]},
        stroke_count: %Schema{type: :integer, example: 4},
        jlpt_level: %Schema{type: :integer, nullable: true, example: 5},
        radicals: %Schema{type: :array, nullable: true, items: %Schema{type: :string}},
        frequency: %Schema{type: :integer, nullable: true},
        school_level: %Schema{type: :integer, nullable: true},
        bg_meanings: %Schema{
          type: :array,
          nullable: true,
          items: %Schema{type: :string},
          description: "Included only when `include=bg_meanings` is requested"
        },
        stroke_data: %Schema{
          type: :object,
          nullable: true,
          description: "SVG stroke path data"
        }
      },
      required: [:character, :meanings, :stroke_count]
    })
  end

  defmodule KanjiListResponse do
    @moduledoc false
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "KanjiListResponse",
      description: "Paginated list of kanji",
      type: :object,
      properties: %{
        items: %Schema{type: :array, items: KanjiListItem},
        next_cursor: %Schema{
          type: :string,
          nullable: true,
          description: "Opaque cursor for the next page"
        }
      },
      required: [:items]
    })
  end

  defmodule ErrorResponse do
    @moduledoc false
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "ErrorResponse",
      description: "API error response",
      type: :object,
      properties: %{
        errors: %Schema{
          type: :array,
          items: %Schema{
            type: :object,
            properties: %{
              detail: %Schema{type: :string},
              title: %Schema{type: :string}
            },
            required: [:detail]
          }
        }
      },
      required: [:errors]
    })
  end

  @doc """
  Returns the OpenApiSpex specification.
  """
  @spec spec() :: OpenApi.t()
  def spec do
    %OpenApi{
      info: %Info{
        title: "Medoru API",
        version: @version,
        description: "Public API for https://medoru.net"
      },
      paths: %{
        "/api/v1/health" => %PathItem{
          get: %Operation{
            operationId: "HealthController.health",
            summary: "Health check",
            responses: %{
              200 => response("OK", HealthResponse)
            }
          }
        },
        "/api/v1/health/db" => %PathItem{
          get: %Operation{
            operationId: "HealthController.db_health",
            summary: "Database health check",
            responses: %{
              200 => response("OK", HealthResponse),
              503 => response("Service Unavailable", ErrorResponse)
            }
          }
        },
        "/api/v1/kanji" => %PathItem{
          get: %Operation{
            operationId: "KanjiController.index",
            summary: "List kanji",
            parameters: [
              parameter("jlpt_level", :query, :integer, "Filter by JLPT level (1-5)",
                minimum: 1,
                maximum: 5
              ),
              parameter("limit", :query, :integer, "Page size (1-100)",
                default: 50,
                minimum: 1,
                maximum: 100
              ),
              parameter("cursor", :query, :string, "Opaque cursor from a previous response"),
              parameter(
                "include",
                :query,
                :string,
                "Comma-separated extra fields. Supported: bg_meanings"
              )
            ],
            responses: %{
              200 => response("OK", KanjiListResponse),
              400 => response("Bad Request", ErrorResponse)
            }
          }
        },
        "/api/v1/kanji/character/{character}" => %PathItem{
          get: %Operation{
            operationId: "KanjiController.show",
            summary: "Get a kanji by character",
            parameters: [
              parameter("character", :path, :string, "Kanji character", required: true),
              parameter(
                "include",
                :query,
                :string,
                "Comma-separated extra fields. Supported: bg_meanings"
              )
            ],
            responses: %{
              200 => response("OK", KanjiDetail),
              404 => response("Not Found", ErrorResponse)
            }
          }
        }
      },
      components: %Components{
        schemas: %{
          HealthResponse => HealthResponse,
          KanjiListItem => KanjiListItem,
          KanjiDetail => KanjiDetail,
          KanjiListResponse => KanjiListResponse,
          ErrorResponse => ErrorResponse
        }
      }
    }
    |> OpenApiSpex.resolve_schema_modules()
  end

  defp response(description, schema) do
    %Response{
      description: description,
      content: %{"application/json" => %MediaType{schema: schema}}
    }
  end

  defp parameter(name, location, type, description, opts \\ []) do
    schema =
      %Schema{type: type}
      |> maybe_put(:minimum, opts[:minimum])
      |> maybe_put(:maximum, opts[:maximum])
      |> maybe_put(:default, opts[:default])

    %OpenApiSpex.Parameter{
      name: name,
      in: location,
      description: description,
      required: Keyword.get(opts, :required, false),
      schema: schema
    }
  end

  defp maybe_put(schema, _key, nil), do: schema
  defp maybe_put(schema, key, value), do: Map.put(schema, key, value)
end

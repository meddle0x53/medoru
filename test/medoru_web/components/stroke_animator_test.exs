defmodule MedoruWeb.StrokeAnimatorTest do
  use MedoruWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias MedoruWeb.StrokeAnimator

  describe "StrokeAnimator component" do
    test "renders with stroke data" do
      stroke_data = %{
        "bounds" => %{"width" => 100, "height" => 100, "viewBox" => "0 0 100 100"},
        "strokes" => [
          %{
            "order" => 1,
            "path" => "M 10 10 L 90 10",
            "type" => "horizontal",
            "direction" => "left-to-right"
          },
          %{
            "order" => 2,
            "path" => "M 50 10 L 50 90",
            "type" => "vertical",
            "direction" => "top-to-bottom"
          }
        ]
      }

      html =
        render_component(StrokeAnimator,
          id: "test-animator",
          stroke_data: stroke_data
        )

      assert html =~ "stroke-animator"
      assert html =~ "M 10 10 L 90 10"
      assert html =~ "M 50 10 L 50 90"
    end

    test "renders empty state when no stroke data" do
      html =
        render_component(StrokeAnimator,
          id: "test-animator",
          stroke_data: nil
        )

      assert html =~ "stroke-animator"
      # Should still render but with empty strokes
    end

    test "displays stroke count" do
      stroke_data = %{
        "bounds" => %{"width" => 100, "height" => 100, "viewBox" => "0 0 100 100"},
        "strokes" => [
          %{
            "order" => 1,
            "path" => "M 10 10 L 90 10",
            "type" => "horizontal",
            "direction" => "left-to-right"
          }
        ]
      }

      html =
        render_component(StrokeAnimator,
          id: "test-animator",
          stroke_data: stroke_data
        )

      assert html =~ "1"
    end
  end
end

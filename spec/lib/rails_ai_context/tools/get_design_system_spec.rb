# frozen_string_literal: true

require "spec_helper"

RSpec.describe RailsAiContext::Tools::GetDesignSystem do
  before { described_class.reset_cache! }

  let(:view_templates_data) do
    {
      ui_patterns: {
        components: [
          {
            type: :button,
            label: "Primary Button",
            classes: "bg-blue-600 text-white px-4 py-2 rounded-lg",
            variants: [
              { classes: "bg-blue-600 text-white px-4 py-2 rounded-lg", count: 8 },
              { classes: "bg-gray-200 text-gray-800 px-4 py-2 rounded-lg", count: 3 }
            ]
          },
          {
            type: :card,
            label: "Card",
            classes: "bg-white rounded-2xl p-6 shadow-sm border border-gray-100",
            variants: [
              { classes: "bg-white rounded-2xl p-6 shadow-sm border border-gray-100", count: 5 }
            ]
          },
          {
            type: :input,
            label: "Input Field",
            classes: "border border-gray-300 rounded-md px-3 py-2",
            variants: []
          }
        ],
        color_scheme: {
          primary: "blue-600",
          danger: "red-600",
          success: "green-600",
          warning: "yellow-500",
          text: "gray-900",
          background_palette: %w[white gray-50 gray-100],
          text_palette: %w[gray-900 gray-700 gray-500],
          border_palette: %w[gray-100 gray-200 gray-300]
        },
        typography: {
          heading_styles: { "h1" => "text-3xl font-bold", "h2" => "text-2xl font-semibold" },
          sizes: { "text-sm" => 5, "text-base" => 10, "text-lg" => 3 },
          weights: { "font-bold" => 8, "font-semibold" => 5 },
          line_height: { "leading-tight" => 2 }
        },
        layout: {
          containers: { "max-w-7xl" => 3, "container" => 2 },
          grid: { "grid-cols-2" => 4, "grid-cols-3" => 2 },
          flex: { "flex" => 15, "items-center" => 10 },
          spacing_scale: { "p-4" => 20, "p-6" => 12, "mb-4" => 8, "gap-4" => 7 }
        },
        form_layout: {
          spacing: "space-y-6",
          grid: "grid grid-cols-2 gap-4"
        },
        responsive: {
          "md:" => { "md:grid-cols-2" => 4, "md:flex" => 3 },
          "lg:" => { "lg:grid-cols-3" => 2 }
        },
        interactive_states: {
          "hover" => { "hover:bg-blue-700" => 5 },
          "focus" => { "focus:ring-2" => 3 }
        },
        dark_mode: { used: false },
        canonical_examples: [
          {
            type: :form_page,
            template: "posts/new.html.erb",
            components_used: %w[Input Button],
            snippet: "<%= form_with model: @post do |f| %>\n  <%= f.text_field :title, class: \"border rounded px-3\" %>\n  <%= f.submit \"Save\", class: \"bg-blue-600 text-white\" %>\n<% end %>"
          }
        ],
        radius: { "default" => "rounded-lg", "card" => "rounded-2xl" },
        icons: nil,
        animations: nil
      }
    }
  end

  let(:design_tokens_data) do
    {
      framework: "Tailwind CSS",
      categorized: {
        colors: { "primary" => "#3b82f6", "danger" => "#ef4444" },
        spacing: { "sm" => "0.5rem", "md" => "1rem", "lg" => "1.5rem" }
      },
      font_loading: { "inter" => "Google Fonts" }
    }
  end

  before do
    allow(described_class).to receive(:cached_context).and_return({
      view_templates: view_templates_data,
      design_tokens: design_tokens_data,
      components: { error: "not available" },
      accessibility: { error: "not available" }
    })
  end

  describe ".call" do
    context "with detail:summary" do
      it "returns design system heading" do
        result = described_class.call(detail: "summary")
        text = result.content.first[:text]
        expect(text).to include("# Design System")
      end

      it "includes color palette" do
        result = described_class.call(detail: "summary")
        text = result.content.first[:text]
        expect(text).to include("Color Palette")
        expect(text).to include("blue-600")
        expect(text).to include("Primary")
      end

      it "includes component class strings" do
        result = described_class.call(detail: "summary")
        text = result.content.first[:text]
        expect(text).to include("Primary Button")
        expect(text).to include("bg-blue-600")
      end

      it "does not include canonical page examples at summary" do
        result = described_class.call(detail: "summary")
        text = result.content.first[:text]
        expect(text).not_to include("Page Examples")
      end
    end

    context "with detail:standard" do
      it "includes canonical HTML examples for components" do
        result = described_class.call(detail: "standard")
        text = result.content.first[:text]
        expect(text).to include("CANONICAL")
        expect(text).to include("<button")
      end

      it "includes canonical page examples" do
        result = described_class.call(detail: "standard")
        text = result.content.first[:text]
        expect(text).to include("Page Examples")
        expect(text).to include("Form Page")
      end

      it "includes design rules" do
        result = described_class.call(detail: "standard")
        text = result.content.first[:text]
        expect(text).to include("Design Rules")
      end

      it "includes ERB examples for input fields" do
        result = described_class.call(detail: "standard")
        text = result.content.first[:text]
        expect(text).to include("```erb")
        expect(text).to include("f.text_field")
      end
    end

    context "with detail:full" do
      it "includes typography section" do
        result = described_class.call(detail: "full")
        text = result.content.first[:text]
        expect(text).to include("Typography")
        expect(text).to include("text-3xl font-bold")
      end

      it "includes layout and spacing" do
        result = described_class.call(detail: "full")
        text = result.content.first[:text]
        expect(text).to include("Layout & Spacing")
        expect(text).to include("max-w-7xl")
      end

      it "includes responsive breakpoints" do
        result = described_class.call(detail: "full")
        text = result.content.first[:text]
        expect(text).to include("Responsive Breakpoints")
        expect(text).to include("md:")
        expect(text).to include("lg:")
      end

      it "includes interactive states" do
        result = described_class.call(detail: "full")
        text = result.content.first[:text]
        expect(text).to include("Interactive States")
        expect(text).to include("hover")
        expect(text).to include("focus")
      end

      it "includes design tokens" do
        result = described_class.call(detail: "full")
        text = result.content.first[:text]
        expect(text).to include("Design Tokens")
        expect(text).to include("Tailwind CSS")
        expect(text).to include("Spacing")
      end

      it "includes font loading info" do
        result = described_class.call(detail: "full")
        text = result.content.first[:text]
        expect(text).to include("Font Loading")
        expect(text).to include("inter")
      end

      it "shows component variants used 2+ times" do
        result = described_class.call(detail: "full")
        text = result.content.first[:text]
        expect(text).to include("variant:")
        expect(text).to include("bg-gray-200")
      end
    end
  end

  describe "edge cases" do
    it "handles missing view templates data" do
      allow(described_class).to receive(:cached_context).and_return({})
      result = described_class.call
      text = result.content.first[:text]
      expect(text).to include("No view templates found")
    end

    it "handles view templates with error" do
      allow(described_class).to receive(:cached_context).and_return({
        view_templates: { error: "something broke" }
      })
      result = described_class.call
      text = result.content.first[:text]
      expect(text).to include("No view templates found")
    end

    it "handles empty components list" do
      allow(described_class).to receive(:cached_context).and_return({
        view_templates: { ui_patterns: { components: [] } }
      })
      result = described_class.call
      text = result.content.first[:text]
      expect(text).to include("No UI components detected")
    end

    it "handles dark mode when enabled" do
      view_templates_data[:ui_patterns][:dark_mode] = { used: true, patterns: { "dark:bg-gray-800" => 3 } }
      result = described_class.call(detail: "full")
      text = result.content.first[:text]
      expect(text).to include("Dark Mode")
      expect(text).to include("dark:")
    end

    it "handles nil design tokens gracefully" do
      allow(described_class).to receive(:cached_context).and_return({
        view_templates: view_templates_data,
        design_tokens: nil,
        components: { error: "not available" },
        accessibility: { error: "not available" }
      })
      result = described_class.call(detail: "full")
      text = result.content.first[:text]
      expect(text).to include("Design System")
    end
  end
end

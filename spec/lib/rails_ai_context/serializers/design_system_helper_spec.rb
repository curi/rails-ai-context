# frozen_string_literal: true

require "spec_helper"

RSpec.describe RailsAiContext::Serializers::DesignSystemHelper do
  let(:test_class) do
    Class.new do
      include RailsAiContext::Serializers::DesignSystemHelper

      attr_reader :context

      def initialize(context)
        @context = context
      end
    end
  end

  describe "#render_design_system" do
    it "returns empty array when view_templates is missing" do
      helper = test_class.new({})
      expect(helper.render_design_system).to eq([])
    end

    it "returns empty array when view_templates has an error" do
      helper = test_class.new({ view_templates: { error: "not found" } })
      expect(helper.render_design_system).to eq([])
    end

    it "returns empty array when components are empty" do
      ctx = { view_templates: { ui_patterns: { components: [] } } }
      helper = test_class.new(ctx)
      expect(helper.render_design_system).to eq([])
    end

    it "renders Design System header with components present" do
      ctx = {
        view_templates: {
          ui_patterns: {
            components: [
              { type: :button, label: "primary button", classes: "btn btn-primary" },
              { type: :button, label: "danger button", classes: "btn btn-danger" },
              { type: :input, label: "text input", classes: "form-control" }
            ]
          }
        },
        design_tokens: nil
      }
      helper = test_class.new(ctx)
      lines = helper.render_design_system
      expect(lines).to include("## Design System")
      expect(lines.join("\n")).to include("Components")
    end

    it "renders color palette when color_scheme is present" do
      ctx = {
        view_templates: {
          ui_patterns: {
            components: [ { type: :button, label: "primary", classes: "btn-primary" } ],
            color_scheme: { primary: "blue-600", danger: "red-500", success: "green-500" }
          }
        },
        design_tokens: nil
      }
      helper = test_class.new(ctx)
      lines = helper.render_design_system
      text = lines.join("\n")
      expect(text).to include("Colors")
      expect(text).to include("blue-600")
      expect(text).to include("Danger")
    end

    it "renders typography summary when present" do
      ctx = {
        view_templates: {
          ui_patterns: {
            components: [ { type: :button, label: "btn", classes: "btn" } ],
            typography: { heading_styles: { "h1" => "text-4xl", "h2" => "text-2xl" }, sizes: { "sm" => "text-sm", "lg" => "text-lg" } }
          }
        },
        design_tokens: nil
      }
      helper = test_class.new(ctx)
      text = helper.render_design_system.join("\n")
      expect(text).to include("Typography")
      expect(text).to include("h1")
      expect(text).to include("text-4xl")
    end

    it "respects max_lines parameter" do
      ctx = {
        view_templates: {
          ui_patterns: {
            components: 20.times.map { |i| { type: :button, label: "btn#{i}", classes: "btn-#{i}" } },
            color_scheme: { primary: "blue", danger: "red", success: "green", warning: "yellow" },
            typography: { heading_styles: { "h1" => "a", "h2" => "b", "h3" => "c" } },
            interactive_states: { "hover" => %w[hover:opacity-80], "focus" => %w[focus:ring-2] }
          }
        },
        design_tokens: nil
      }
      helper = test_class.new(ctx)
      lines = helper.render_design_system(ctx, max_lines: 10)
      expect(lines.size).to be <= 10
    end

    it "renders interactive states when present" do
      ctx = {
        view_templates: {
          ui_patterns: {
            components: [ { type: :button, label: "btn", classes: "btn" } ],
            interactive_states: { "hover" => { "hover:bg-gray-100" => 3 }, "focus" => { "focus:ring-2" => 5 } }
          }
        },
        design_tokens: nil
      }
      helper = test_class.new(ctx)
      text = helper.render_design_system.join("\n")
      expect(text).to include("Interactive States")
      expect(text).to include("hover")
      expect(text).to include("focus")
    end

    it "renders dark mode summary when used" do
      ctx = {
        view_templates: {
          ui_patterns: {
            components: [ { type: :button, label: "btn", classes: "btn" } ],
            dark_mode: { used: true, patterns: { "dark:bg-gray-900" => 10, "dark:text-white" => 8 } }
          }
        },
        design_tokens: nil
      }
      helper = test_class.new(ctx)
      text = helper.render_design_system.join("\n")
      expect(text).to include("Dark Mode")
      expect(text).to include("dark:")
    end

    it "renders decision guide when 3+ components exist" do
      ctx = {
        view_templates: {
          ui_patterns: {
            components: [
              { type: :button, label: "primary button", classes: "btn-primary" },
              { type: :button, label: "danger button", classes: "btn-danger" },
              { type: :button, label: "secondary button", classes: "btn-secondary" }
            ]
          }
        },
        design_tokens: nil
      }
      helper = test_class.new(ctx)
      text = helper.render_design_system.join("\n")
      expect(text).to include("When to Use What")
      expect(text).to include("Primary action")
      expect(text).to include("Destructive action")
    end
  end

  describe "#render_design_system_full" do
    it "includes canonical examples when present" do
      ctx = {
        view_templates: {
          ui_patterns: {
            components: [ { type: :button, label: "btn", classes: "btn" } ],
            canonical_examples: [
              { type: :form_page, template: "users/new.html.erb", snippet: "<%= form_with model: @user do |f| %>\n  <%= f.text_field :name %>\n<% end %>" }
            ]
          }
        },
        design_tokens: nil
      }
      helper = test_class.new(ctx)
      text = helper.render_design_system_full.join("\n")
      expect(text).to include("Page Examples")
      expect(text).to include("Form Page")
      expect(text).to include("form_with")
    end

    it "caps canonical examples at 3 and shows overflow message" do
      examples = 5.times.map do |i|
        { type: :form_page, template: "t#{i}.erb", snippet: "<p>#{i}</p>" }
      end
      ctx = {
        view_templates: {
          ui_patterns: {
            components: [ { type: :button, label: "btn", classes: "btn" } ],
            canonical_examples: examples
          }
        },
        design_tokens: nil
      }
      helper = test_class.new(ctx)
      text = helper.render_design_system_full.join("\n")
      expect(text).to include("2 more examples available")
    end

    it "renders responsive breakpoints when present" do
      ctx = {
        view_templates: {
          ui_patterns: {
            components: [ { type: :button, label: "btn", classes: "btn" } ],
            responsive: { "sm" => { "sm:grid-cols-1" => 3 }, "md" => { "md:grid-cols-2" => 5 } }
          }
        },
        design_tokens: nil
      }
      helper = test_class.new(ctx)
      text = helper.render_design_system_full.join("\n")
      expect(text).to include("Responsive Breakpoints")
      expect(text).to include("sm")
      expect(text).to include("md")
    end

    it "renders shared partials section when present" do
      ctx = {
        view_templates: {
          ui_patterns: {
            components: [ { type: :button, label: "btn", classes: "btn" } ],
            shared_partials: [
              { name: "_flash_messages.html.erb", description: "Flash notification bar" }
            ]
          }
        },
        design_tokens: nil
      }
      helper = test_class.new(ctx)
      text = helper.render_design_system_full.join("\n")
      expect(text).to include("Shared Partials")
      expect(text).to include("_flash_messages.html.erb")
    end
  end
end

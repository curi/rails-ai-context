# frozen_string_literal: true

module RailsAiContext
  module Serializers
    # Generates .github/instructions/*.instructions.md files with applyTo frontmatter
    # for GitHub Copilot path-specific instructions.
    class CopilotInstructionsSerializer
      include StackOverviewHelper
      include DesignSystemHelper
      include ToolGuideHelper

      attr_reader :context

      def initialize(context)
        @context = context
      end

      def call(output_dir)
        dir = File.join(output_dir, ".github", "instructions")

        files = {
          File.join(dir, "rails-context.instructions.md") => render_context_instructions,
          File.join(dir, "rails-models.instructions.md") => render_models_instructions,
          File.join(dir, "rails-controllers.instructions.md") => render_controllers_instructions,
          File.join(dir, "rails-ui-patterns.instructions.md") => render_ui_patterns_instructions,
          File.join(dir, "rails-mcp-tools.instructions.md") => render_mcp_tools_instructions
        }

        write_rule_files(files)
      end

      private

      def render_context_instructions
        lines = [
          "---",
          "applyTo: \"**/*\"",
          "---",
          "",
          "# #{context[:app_name] || 'Rails App'} — Overview",
          "",
          "Rails #{context[:rails_version]} | Ruby #{context[:ruby_version]}",
          ""
        ]

        schema = context[:schema]
        if schema.is_a?(Hash) && !schema[:error]
          lines << "- Database: #{schema[:adapter]} — #{schema[:total_tables]} tables"
        end

        models = context[:models]
        lines << "- Models: #{models.size}" if models.is_a?(Hash) && !models[:error]

        routes = context[:routes]
        lines << "- Routes: #{routes[:total_routes]}" if routes.is_a?(Hash) && !routes[:error]

        gems = context[:gems]
        if gems.is_a?(Hash) && !gems[:error]
          notable = gems[:notable_gems] || []
          notable.group_by { |g| g[:category]&.to_s || "other" }.first(6).each do |cat, gem_list|
            lines << "- #{cat}: #{gem_list.map { |g| g[:name] }.join(', ')}"
          end
        end

        conv = context[:conventions]
        if conv.is_a?(Hash) && !conv[:error]
          arch_labels = arch_labels_hash
          (conv[:architecture] || []).first(5).each { |p| lines << "- #{arch_labels[p] || p}" }
        end

        lines.concat(full_preset_stack_lines)

        # List service objects
        services = detect_service_files
        lines << "- Services: #{services.join(', ')}" if services.any?

        # List jobs
        jobs = detect_job_files
        lines << "- Jobs: #{jobs.join(', ')}" if jobs.any?

        # ApplicationController before_actions
        before_actions = detect_before_actions
        lines << "" << "**Global before_actions:** #{before_actions.join(', ')}" if before_actions.any?

        lines << ""
        lines << "Use MCP tools for detailed data. Start with `detail:\"summary\"`."

        lines.join("\n")
      end

      def render_models_instructions
        models = context[:models]
        return nil unless models.is_a?(Hash) && !models[:error] && models.any?

        lines = [
          "---",
          "applyTo: \"app/models/**/*.rb\"",
          "---",
          "",
          "# ActiveRecord Models (#{models.size})",
          "",
          "Check here first for scopes, constants, associations. Read model files for business logic/methods.",
          ""
        ]

        models.keys.sort.first(30).each do |name|
          data = models[name]
          assocs = (data[:associations] || []).size
          lines << "- #{name} (#{assocs} associations)"
          scopes = (data[:scopes] || [])
          constants = (data[:constants] || [])
          if scopes.any? || constants.any?
            extras = []
            scope_names = scope_names(scopes)
            extras << "scopes: #{scope_names.join(', ')}" if scopes.any?
            constants.each { |c| extras << "#{c[:name]}: #{c[:values].join(', ')}" }
            lines << "  #{extras.join(' | ')}"
          end
        end

        lines << "- ...#{models.size - 30} more" if models.size > 30
        lines.join("\n")
      end

      def render_controllers_instructions
        data = context[:controllers]
        return nil unless data.is_a?(Hash) && !data[:error]
        controllers = data[:controllers] || {}
        return nil if controllers.empty?

        lines = [
          "---",
          "applyTo: \"app/controllers/**/*.rb\"",
          "---",
          "",
          "# Controllers (#{controllers.size})",
          "",
          "Use `rails_get_controllers` MCP tool for full details.",
          ""
        ]

        controllers.keys.sort.first(25).each do |name|
          info = controllers[name]
          actions = info[:actions]&.size || 0
          lines << "- #{name} (#{actions} actions)"
        end

        lines.join("\n")
      end

      def render_ui_patterns_instructions
        vt = context[:view_templates]
        return nil unless vt.is_a?(Hash) && !vt[:error]
        components = vt.dig(:ui_patterns, :components) || []
        return nil if components.empty?

        lines = [
          "---",
          "applyTo: \"app/views/**/*.erb\"",
          "---",
          ""
        ]

        lines.concat(render_design_system_full(context))

        # Stimulus controllers
        stim = context[:stimulus]
        if stim.is_a?(Hash) && !stim[:error]
          controllers = stim[:controllers] || []
          if controllers.any?
            names = controllers.map { |c| c[:name] || c[:file]&.gsub("_controller.js", "") }.compact.sort
            lines << "" << "## Stimulus controllers"
            lines << names.join(", ")
          end
        end

        lines.join("\n")
      end

      def render_mcp_tools_instructions
        lines = [
          "---",
          "applyTo: \"**/*\"",
          "excludeAgent: \"code-review\"",
          "---",
          ""
        ]

        lines.concat(render_tools_guide)

        lines.join("\n")
      end
    end
  end
end

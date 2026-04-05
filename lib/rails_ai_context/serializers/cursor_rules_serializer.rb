# frozen_string_literal: true

module RailsAiContext
  module Serializers
    # Generates .cursor/rules/*.mdc files in the new Cursor MDC format.
    # Each file is focused, <50 lines, with YAML frontmatter.
    # .cursorrules is deprecated by Cursor; this is the recommended format.
    class CursorRulesSerializer
      include StackOverviewHelper
      include ToolGuideHelper

      attr_reader :context

      def initialize(context)
        @context = context
      end

      # @param output_dir [String] Rails root path
      # @return [Hash] { written: [paths], skipped: [paths] }
      def call(output_dir)
        rules_dir = File.join(output_dir, ".cursor", "rules")

        files = {
          File.join(rules_dir, "rails-project.mdc") => render_project_rule,
          File.join(rules_dir, "rails-models.mdc") => render_models_rule,
          File.join(rules_dir, "rails-controllers.mdc") => render_controllers_rule,
          File.join(rules_dir, "rails-mcp-tools.mdc") => render_mcp_tools_rule
        }

        write_rule_files(files)
      end

      private

      # Always-on project overview rule (<50 lines)
      def render_project_rule
        lines = [
          "---",
          "description: \"Rails project context for #{context[:app_name]}\"",
          "alwaysApply: true",
          "---",
          "",
          "# #{context[:app_name]}",
          "",
          "Rails #{context[:rails_version]} | Ruby #{context[:ruby_version]}",
          ""
        ]

        schema = context[:schema]
        if schema && !schema[:error]
          lines << "- Database: #{schema[:adapter]} — #{schema[:total_tables]} tables"
        end

        models = context[:models]
        lines << "- Models: #{models.size}" if models.is_a?(Hash) && !models[:error]

        routes = context[:routes]
        if routes && !routes[:error]
          lines << "- Routes: #{routes[:total_routes]}"
        end

        gems = context[:gems]
        if gems.is_a?(Hash) && !gems[:error]
          notable = notable_gems_list(gems)
          grouped = notable.group_by { |g| g[:category]&.to_s || "other" }
          grouped.each do |cat, gem_list|
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
        lines << "" << "Global before_actions: #{before_actions.join(', ')}" if before_actions.any?

        lines << ""
        lines << "MCP tools available — see rails-mcp-tools.mdc for full reference."
        lines << "Always call with detail:\"summary\" first, then drill into specifics."

        lines.join("\n")
      end

      # Auto-attached when working in app/models/
      def render_models_rule
        models = context[:models]
        return nil unless models.is_a?(Hash) && !models[:error] && models.any?

        lines = [
          "---",
          "globs:",
          "  - \"app/models/**/*.rb\"",
          "alwaysApply: false",
          "---",
          "",
          "# Models (#{models.size})",
          ""
        ]

        lines << "Check here first for scopes, constants, associations. Read model files for business logic/methods."
        lines << ""

        models.keys.sort.first(30).each do |name|
          data = models[name]
          assocs = (data[:associations] || []).size
          lines << "- #{name} (#{assocs} associations, table: #{data[:table_name] || '?'})"
          extras = model_extras_line(data)
          lines << extras if extras
        end

        lines << "- ...#{models.size - 30} more" if models.size > 30
        lines << ""
        lines << "Use `rails_get_model_details` MCP tool with model:\"Name\" for full detail."

        lines.join("\n")
      end

      # Auto-attached when working in app/controllers/
      def render_controllers_rule
        data = context[:controllers]
        return nil unless data.is_a?(Hash) && !data[:error]
        controllers = data[:controllers] || {}
        return nil if controllers.empty?

        lines = [
          "---",
          "globs:",
          "  - \"app/controllers/**/*.rb\"",
          "alwaysApply: false",
          "---",
          "",
          "# Controllers (#{controllers.size})",
          ""
        ]

        lines.concat(render_compact_controllers_list(controllers))

        lines << ""
        lines << "Use `rails_get_controllers` MCP tool with controller:\"Name\" for full detail."

        lines.join("\n")
      end

      # Always-on MCP tool reference — strongest enforcement point for Cursor
      def render_mcp_tools_rule
        lines = [
          "---",
          "description: \"Rails tools (#{tool_count}) — MANDATORY, use before reading any reference files\"",
          "alwaysApply: true",
          "---",
          ""
        ]

        lines.concat(render_tools_guide)

        lines.join("\n")
      end
    end
  end
end

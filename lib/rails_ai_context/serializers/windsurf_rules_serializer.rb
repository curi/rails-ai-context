# frozen_string_literal: true

module RailsAiContext
  module Serializers
    # Generates .windsurf/rules/*.md files in the new Windsurf rules format.
    # Each file is hard-capped at 5,800 characters (within Windsurf's 6K limit).
    class WindsurfRulesSerializer
      MAX_CHARS_PER_FILE = 5_800

      attr_reader :context

      def initialize(context)
        @context = context
      end

      def call(output_dir)
        rules_dir = File.join(output_dir, ".windsurf", "rules")
        FileUtils.mkdir_p(rules_dir)

        written = []
        skipped = []

        files = {
          "rails-context.md" => render_context_rule
        }

        files.each do |filename, content|
          next unless content
          # Enforce Windsurf's 6K limit
          content = content[0...MAX_CHARS_PER_FILE] if content.length > MAX_CHARS_PER_FILE

          filepath = File.join(rules_dir, filename)
          if File.exist?(filepath) && File.read(filepath) == content
            skipped << filepath
          else
            File.write(filepath, content)
            written << filepath
          end
        end

        { written: written, skipped: skipped }
      end

      private

      def render_context_rule
        # Reuse WindsurfSerializer content
        WindsurfSerializer.new(context).call
      end
    end
  end
end

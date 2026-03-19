# frozen_string_literal: true

module RailsAiContext
  module Introspectors
    # Reads actual view template contents and extracts metadata:
    # partial references, Stimulus controller usage, line counts.
    # Separate from ViewIntrospector which focuses on structural discovery.
    class ViewTemplateIntrospector
      attr_reader :app

      def initialize(app)
        @app = app
      end

      def call
        views_dir = File.join(app.root.to_s, "app", "views")
        return { templates: {}, partials: {} } unless Dir.exist?(views_dir)

        {
          templates: scan_templates(views_dir),
          partials: scan_partials(views_dir)
        }
      rescue => e
        { error: e.message }
      end

      private

      def scan_templates(views_dir)
        templates = {}
        Dir.glob(File.join(views_dir, "**", "*")).each do |path|
          next if File.directory?(path)
          next if File.basename(path).start_with?("_") # skip partials
          next if path.include?("/layouts/")

          relative = path.sub("#{views_dir}/", "")
          content = File.read(path) rescue next
          templates[relative] = {
            lines: content.lines.count,
            partials: extract_partial_refs(content),
            stimulus: extract_stimulus_refs(content)
          }
        end
        templates
      end

      def scan_partials(views_dir)
        partials = {}
        Dir.glob(File.join(views_dir, "**", "_*")).each do |path|
          next if File.directory?(path)
          relative = path.sub("#{views_dir}/", "")
          lines = File.read(path).lines.count rescue 0
          partials[relative] = { lines: lines }
        end
        partials
      end

      def extract_partial_refs(content)
        refs = []
        # render "partial_name" or render partial: "name"
        content.scan(/render\s+(?:partial:\s*)?["']([^"']+)["']/).each { |m| refs << m[0] }
        # render @collection
        content.scan(/render\s+@(\w+)/).each { |m| refs << m[0] }
        refs.uniq
      end

      def extract_stimulus_refs(content)
        refs = []
        # data-controller="name" or data-controller="name1 name2"
        content.scan(/data-controller=["']([^"']+)["']/).each do |m|
          m[0].split.each { |c| refs << c }
        end
        # data: { controller: "name" }
        content.scan(/controller:\s*["']([^"']+)["']/).each do |m|
          m[0].split.each { |c| refs << c }
        end
        refs.uniq
      end
    end
  end
end

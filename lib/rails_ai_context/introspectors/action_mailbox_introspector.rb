# frozen_string_literal: true

module RailsAiContext
  module Introspectors
    # Discovers Action Mailbox setup: mailbox classes, routing patterns.
    class ActionMailboxIntrospector
      attr_reader :app

      def initialize(app)
        @app = app
      end

      def call
        {
          installed: defined?(ActionMailbox) ? true : false,
          mailboxes: extract_mailboxes
        }
      rescue => e
        { error: e.message }
      end

      private

      def root
        app.root.to_s
      end

      def extract_mailboxes
        dir = File.join(root, "app/mailboxes")
        return [] unless Dir.exist?(dir)

        Dir.glob(File.join(dir, "**/*.rb")).filter_map do |path|
          relative = path.sub("#{dir}/", "")
          next if relative == "application_mailbox.rb"

          content = File.read(path)
          name = File.basename(path, ".rb").camelize

          routing = content.scan(/routing\s+(.+?)\s+=>\s+:(\w+)/).map do |match|
            { pattern: match[0], action: match[1] }
          end

          # Extract callbacks
          callbacks = content.scan(/\b(before_processing|after_processing|around_processing)\s+:(\w+)/).map do |type, method|
            { type: type, method: method }
          end

          entry = { name: name, file: relative, routing: routing }
          entry[:callbacks] = callbacks if callbacks.any?
          entry
        rescue => e
          $stderr.puts "[rails-ai-context] extract_mailboxes failed: #{e.message}" if ENV["DEBUG"]
          nil
        end.sort_by { |m| m[:name] }
      end
    end
  end
end

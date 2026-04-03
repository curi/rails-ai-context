# frozen_string_literal: true

module RailsAiContext
  module Introspectors
    # Discovers background jobs (ActiveJob/Sidekiq), mailers,
    # and Action Cable channels.
    class JobIntrospector
      attr_reader :app

      def initialize(app)
        @app = app
      end

      # @return [Hash] async workers, mailers, and channels
      def call
        jobs = extract_jobs
        # Source parsing fallback when runtime reflection yields no results
        jobs = extract_jobs_from_source if jobs.empty?

        {
          jobs: jobs,
          mailers: extract_mailers,
          channels: extract_channels,
          recurring_jobs: extract_solid_queue_recurring,
          sidekiq_config: extract_sidekiq_config
        }
      end

      private

      def extract_jobs
        return [] unless defined?(ActiveJob::Base)

        ActiveJob::Base.descendants.filter_map do |job|
          next if job.name.nil? || job.name == "ApplicationJob" ||
                  job.name.start_with?("ActionMailer", "ActiveStorage::", "ActionMailbox::", "Turbo::", "Sentry::")

          queue = job.queue_name
          queue = begin queue.call rescue "default" end if queue.is_a?(Proc)

          {
            name: job.name,
            queue: queue.to_s,
            priority: job.priority
          }.compact
        end.sort_by { |j| j[:name] }
      rescue => e
        $stderr.puts "[rails-ai-context] extract_jobs failed: #{e.message}" if ENV["DEBUG"]
        []
      end

      def extract_jobs_from_source
        jobs_dir = File.join(app.root, "app", "jobs")
        return [] unless Dir.exist?(jobs_dir)

        Dir.glob(File.join(jobs_dir, "**/*.rb")).filter_map do |path|
          source = File.read(path) rescue next

          # Extract class name
          class_match = source.match(/class\s+(\S+)\s*</)
          next unless class_match
          name = class_match[1]
          next if name == "ApplicationJob"

          # Extract queue_as
          queue_match = source.match(/queue_as\s+:(\w+)/)
          queue = queue_match ? queue_match[1] : nil

          # Extract retry_on declarations
          retry_on = source.scan(/retry_on\s+(.+?)$/).map { |m| m[0].strip }

          # Extract discard_on declarations
          discard_on = source.scan(/discard_on\s+(.+?)$/).map { |m| m[0].strip }

          # Extract perform method signature
          perform_match = source.match(/def\s+perform\s*\(([^)]*)\)/)
          perform_signature = perform_match ? perform_match[1].strip : nil

          callbacks = source.scan(/\b(before_enqueue|after_enqueue|before_perform|after_perform|around_perform|around_enqueue)\b/).flatten.uniq

          job = { name: name }
          job[:queue] = queue if queue
          job[:retry_on] = retry_on if retry_on.any?
          job[:discard_on] = discard_on if discard_on.any?
          job[:perform_signature] = perform_signature if perform_signature
          job[:callbacks] = callbacks if callbacks.any?
          job
        end.sort_by { |j| j[:name] }
      rescue => e
        $stderr.puts "[rails-ai-context] extract_jobs_from_source failed: #{e.message}" if ENV["DEBUG"]
        []
      end

      def extract_solid_queue_recurring
        paths = [
          File.join(app.root, "config", "recurring.yml"),
          File.join(app.root, "config", "solid_queue.yml")
        ]
        path = paths.find { |p| File.exist?(p) }
        return [] unless path

        content = File.read(path)
        jobs = []
        content.scan(/(\w+):\s*\n\s+class:\s*(\w+).*?(?:schedule:\s*["']?([^"'\n]+))?/m) do |name, klass, schedule|
          jobs << { name: name, class: klass, schedule: schedule&.strip }.compact
        end
        jobs
      rescue => e
        $stderr.puts "[rails-ai-context] extract_solid_queue_recurring failed: #{e.message}" if ENV["DEBUG"]
        []
      end

      def extract_sidekiq_config
        path = File.join(app.root, "config", "sidekiq.yml")
        return nil unless File.exist?(path)

        content = File.read(path)
        config = {}
        config[:concurrency] = $1.to_i if content.match(/concurrency:\s*(\d+)/)
        queues = content.scan(/-\s*(?:\[?\s*)?(\w+)/).flatten.uniq
        config[:queues] = queues if queues.any?
        config.empty? ? nil : config
      rescue => e
        $stderr.puts "[rails-ai-context] extract_sidekiq_config failed: #{e.message}" if ENV["DEBUG"]
        nil
      end

      def extract_mailers
        return [] unless defined?(ActionMailer::Base)

        ActionMailer::Base.descendants.filter_map do |mailer|
          next if mailer.name.nil?

          actions = mailer.instance_methods(false).map(&:to_s).sort
          next if actions.empty?

          {
            name: mailer.name,
            actions: actions,
            delivery_method: mailer.delivery_method.to_s
          }
        end.sort_by { |m| m[:name] }
      rescue => e
        $stderr.puts "[rails-ai-context] extract_mailers failed: #{e.message}" if ENV["DEBUG"]
        []
      end

      def extract_channels
        return [] unless defined?(ActionCable::Channel::Base)

        ActionCable::Channel::Base.descendants.filter_map do |channel|
          next if channel.name.nil? || channel.name == "ApplicationCable::Channel"

          {
            name: channel.name,
            stream_methods: channel.instance_methods(false)
              .select { |m| m.to_s.start_with?("stream_") || m == :subscribed }
              .map(&:to_s)
          }
        end.sort_by { |c| c[:name] }
      rescue => e
        $stderr.puts "[rails-ai-context] extract_channels failed: #{e.message}" if ENV["DEBUG"]
        []
      end
    end
  end
end

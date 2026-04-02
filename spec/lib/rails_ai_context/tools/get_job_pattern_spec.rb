# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "fileutils"

RSpec.describe RailsAiContext::Tools::GetJobPattern do
  before { described_class.reset_cache! }

  describe ".call" do
    it "lists all jobs with default params" do
      result = described_class.call
      text = result.content.first[:text]
      expect(text).to be_a(String)
      expect(text.length).to be > 0
      expect(text).to include("Background Jobs")
      expect(text).to include("ExampleJob")
    end

    it "lists jobs with queue names for detail:summary" do
      result = described_class.call(detail: "summary")
      text = result.content.first[:text]
      expect(text).to include("ExampleJob")
      expect(text).to include("default")
    end

    it "lists jobs with retries and dependencies for detail:standard" do
      result = described_class.call(detail: "standard")
      text = result.content.first[:text]
      expect(text).to include("ExampleJob")
    end

    it "shows full detail for all jobs at detail:full" do
      result = described_class.call(detail: "full")
      text = result.content.first[:text]
      expect(text).to include("ExampleJob")
      expect(text).to include("perform")
    end

    it "shows specific job by class name" do
      result = described_class.call(job: "ExampleJob")
      text = result.content.first[:text]
      expect(text).to include("ExampleJob")
      expect(text).to include("Queue:")
      expect(text).to include("default")
      expect(text).to include("perform(user_id)")
    end

    it "shows specific job by snake_case name" do
      result = described_class.call(job: "example")
      text = result.content.first[:text]
      expect(text).to include("ExampleJob")
    end

    it "returns not-found for unknown job" do
      result = described_class.call(job: "NonexistentJob")
      text = result.content.first[:text]
      expect(text).to include("not found")
      expect(text).to include("ExampleJob")
    end

    context "with a rich job fixture" do
      let(:tmpdir) { Dir.mktmpdir }
      let(:jobs_dir) { File.join(tmpdir, "app", "jobs") }

      before do
        FileUtils.mkdir_p(jobs_dir)

        File.write(File.join(jobs_dir, "notify_job.rb"), <<~RUBY)
          class NotifyJob < ApplicationJob
            queue_as :mailers

            retry_on Net::OpenTimeout, attempts: 3, wait: :polynomially_longer
            discard_on ActiveJob::DeserializationError

            def perform(user_id, message:)
              return if User.find_by(id: user_id).nil?

              UserMailer.notification(user_id, message).deliver_later
              Rails.logger.info("Notification sent to user \#{user_id}")
            end
          end
        RUBY

        File.write(File.join(jobs_dir, "cleanup_job.rb"), <<~RUBY)
          class CleanupJob < ApplicationJob
            queue_as :maintenance

            def perform
              Post.where("created_at < ?", 90.days.ago).destroy_all
            end
          end
        RUBY

        allow(Rails).to receive(:root).and_return(Pathname.new(tmpdir))
        allow(RailsAiContext.configuration).to receive(:max_file_size).and_return(1_000_000)
      end

      after { FileUtils.remove_entry(tmpdir) }

      it "extracts queue name from job" do
        result = described_class.call(job: "NotifyJob")
        text = result.content.first[:text]
        expect(text).to include("mailers")
      end

      it "extracts retry and discard configuration" do
        result = described_class.call(job: "NotifyJob")
        text = result.content.first[:text]
        expect(text).to include("retry_on")
        expect(text).to include("discard_on")
      end

      it "extracts perform signature with keyword args" do
        result = described_class.call(job: "NotifyJob")
        text = result.content.first[:text]
        expect(text).to include("perform(user_id, message:)")
      end

      it "detects side effects like email delivery and logging" do
        result = described_class.call(job: "NotifyJob")
        text = result.content.first[:text]
        expect(text).to include("email delivery")
        expect(text).to include("logging")
      end

      it "shows queue summary when listing all jobs" do
        result = described_class.call(detail: "summary")
        text = result.content.first[:text]
        expect(text).to include("Queues:")
        expect(text).to include("mailers")
        expect(text).to include("maintenance")
      end
    end
  end
end

# frozen_string_literal: true

require "spec_helper"

RSpec.describe RailsAiContext::Tools::Validate do
  before { described_class.reset_cache! }

  describe ".call" do
    it "validates a valid Ruby file" do
      result = described_class.call(files: [ "app/models/post.rb" ])
      text = result.content.first[:text]
      expect(text).to include("syntax OK")
      expect(text).to include("1/1 files passed")
    end

    it "detects bad Ruby syntax" do
      tmp_dir = File.join(Rails.root, "tmp")
      FileUtils.mkdir_p(tmp_dir)
      bad_file = File.join(tmp_dir, "bad_syntax_test.rb")
      File.write(bad_file, "def foo\n  puts(\"hello\"\nend")
      begin
        result = described_class.call(files: [ "tmp/bad_syntax_test.rb" ])
        text = result.content.first[:text]
        expect(text).to include("0/1 files passed")
      ensure
        File.delete(bad_file) if File.exist?(bad_file)
      end
    end

    it "returns error for non-existent files" do
      result = described_class.call(files: [ "nonexistent/file.rb" ])
      text = result.content.first[:text]
      expect(text).to include("file not found")
    end

    it "rejects path traversal attempts" do
      result = described_class.call(files: [ "../../etc/passwd" ])
      text = result.content.first[:text]
      expect(text).to match(/not found|not allowed/)
    end

    it "enforces MAX_FILES limit" do
      files = 25.times.map { |i| "app/models/fake#{i}.rb" }
      result = described_class.call(files: files)
      text = result.content.first[:text]
      expect(text).to include("Too many files")
    end

    it "skips unsupported file types" do
      result = described_class.call(files: [ "config/database.yml" ])
      text = result.content.first[:text]
      expect(text).to include("skipped")
    end

    it "returns empty message for no files" do
      result = described_class.call(files: [])
      text = result.content.first[:text]
      expect(text).to include("No files provided")
    end

    it "validates multiple files at once" do
      result = described_class.call(files: [ "app/models/post.rb", "app/models/user.rb" ])
      text = result.content.first[:text]
      expect(text).to include("2/2 files passed")
    end
  end
end

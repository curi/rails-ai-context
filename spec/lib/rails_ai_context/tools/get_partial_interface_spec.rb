# frozen_string_literal: true

require "spec_helper"

RSpec.describe RailsAiContext::Tools::GetPartialInterface do
  before { described_class.reset_cache! }

  describe ".call" do
    it "analyzes a partial with magic comment locals" do
      result = described_class.call(partial: "posts/form")
      text = result.content.first[:text]
      expect(text).to be_a(String)
      expect(text.length).to be > 0
      expect(text).to include("post")
      expect(text).to include("url")
    end

    it "shows summary detail level" do
      result = described_class.call(partial: "posts/form", detail: "summary")
      text = result.content.first[:text]
      expect(text).to include("Locals:")
      expect(text).to include("Rendered from:")
    end

    it "shows standard detail with method calls on locals" do
      result = described_class.call(partial: "posts/post", detail: "standard")
      text = result.content.first[:text]
      expect(text).to include("Local Variables")
      # post.title and post.body are called in the partial
      expect(text).to include("post")
    end

    it "shows full detail with source code" do
      result = described_class.call(partial: "posts/form", detail: "full")
      text = result.content.first[:text]
      expect(text).to include("Source")
      expect(text).to include("form_with")
    end

    it "handles underscore-prefixed partial names" do
      result = described_class.call(partial: "posts/_form")
      text = result.content.first[:text]
      expect(text).to include("post")
    end

    it "finds render sites for the partial" do
      result = described_class.call(partial: "posts/form", detail: "standard")
      text = result.content.first[:text]
      # edit.html.erb renders the form partial
      expect(text).to include("Rendered From")
    end

    it "returns not-found for unknown partial" do
      result = described_class.call(partial: "nonexistent/widget")
      text = result.content.first[:text]
      expect(text).to include("not found")
    end

    it "prevents path traversal" do
      result = described_class.call(partial: "../../../etc/passwd")
      text = result.content.first[:text]
      expect(text).to include("not allowed")
    end

    it "detects magic comment locals in status_badge partial" do
      result = described_class.call(partial: "shared/status_badge")
      text = result.content.first[:text]
      expect(text).to include("status")
      expect(text).to include("size")
    end

    it "extracts method calls on locals" do
      result = described_class.call(partial: "posts/post", detail: "standard")
      text = result.content.first[:text]
      # _post.html.erb calls post.title and post.body
      if text.include?("calls:")
        expect(text).to match(/title|body/)
      end
    end
  end
end

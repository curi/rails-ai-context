# frozen_string_literal: true

require "spec_helper"

RSpec.describe RailsAiContext::Serializers::MarkdownSerializer do
  let(:context) { RailsAiContext.introspect }

  describe "#call" do
    subject(:output) { described_class.new(context).call }

    it "returns a markdown string" do
      expect(output).to be_a(String)
      expect(output).to include("# ")
    end

    it "includes the app overview" do
      expect(output).to include("## Overview")
    end

    it "includes database schema section" do
      expect(output).to include("## Database Schema")
    end

    it "includes routes section" do
      expect(output).to include("## Routes")
    end
  end
end

RSpec.describe RailsAiContext::Serializers::ClaudeSerializer do
  let(:context) { RailsAiContext.introspect }

  describe "#call" do
    subject(:output) { described_class.new(context).call }

    it "includes Claude-specific header" do
      expect(output).to include("Claude Code")
    end

    it "includes behavioral rules section" do
      expect(output).to include("## Behavioral Rules")
    end
  end
end

RSpec.describe RailsAiContext::Serializers::RulesSerializer do
  let(:context) { RailsAiContext.introspect }

  describe "#call" do
    subject(:output) { described_class.new(context).call }

    it "uses compact project rules header" do
      expect(output).to include("Project Rules")
    end
  end
end

RSpec.describe RailsAiContext::Serializers::CopilotSerializer do
  let(:context) { RailsAiContext.introspect }

  describe "#call" do
    subject(:output) { described_class.new(context).call }

    it "uses Copilot-specific header" do
      expect(output).to include("Copilot Instructions")
    end
  end
end

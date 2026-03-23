# frozen_string_literal: true

require "spec_helper"

RSpec.describe RailsAiContext::Doctor do
  let(:doctor) { described_class.new(Rails.application) }

  describe "#run" do
    subject(:result) { doctor.run }

    it "returns checks and a score" do
      expect(result).to have_key(:checks)
      expect(result).to have_key(:score)
    end

    it "returns an array of checks" do
      expect(result[:checks]).to all(be_a(RailsAiContext::Doctor::Check))
    end

    it "computes a score between 0 and 100" do
      expect(result[:score]).to be_between(0, 100)
    end

    it "checks schema presence" do
      names = result[:checks].map(&:name)
      expect(names).to include("Schema")
    end

    it "includes core checks" do
      names = result[:checks].map(&:name)
      expect(names).to include("Controllers", "Views", "Tests", "MCP server")
    end

    it "includes deep checks" do
      names = result[:checks].map(&:name)
      expect(names).to include("Context files", "Preset coverage", "Secrets in .gitignore", "MCP auto_mount")
    end

    it "runs at least 15 checks" do
      expect(result[:checks].size).to be >= 15
    end

    it "checks MCP server buildability" do
      mcp_check = result[:checks].find { |c| c.name == "MCP server" }
      expect(mcp_check.status).to eq(:pass)
    end

    it "all checks have a name and message" do
      result[:checks].each do |check|
        expect(check.name).to be_a(String)
        expect(check.message).to be_a(String)
        expect(%i[pass warn fail]).to include(check.status)
      end
    end

    it "checks security settings" do
      auto_mount = result[:checks].find { |c| c.name == "MCP auto_mount" }
      expect(auto_mount).not_to be_nil
      expect(auto_mount.status).to eq(:pass)
    end

    it "checks preset coverage" do
      preset = result[:checks].find { |c| c.name == "Preset coverage" }
      expect(preset).not_to be_nil
    end
  end
end

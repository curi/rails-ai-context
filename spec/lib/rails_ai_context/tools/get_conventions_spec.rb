# frozen_string_literal: true

require "spec_helper"

RSpec.describe RailsAiContext::Tools::GetConventions do
  before { described_class.reset_cache! }

  let(:conventions_data) do
    {
      architecture: %w[hotwire service_objects docker],
      patterns: %w[sti polymorphic soft_delete],
      directory_structure: {
        "app/models" => 12,
        "app/controllers" => 8,
        "app/services" => 5,
        "app/views" => 20,
        "app/jobs" => 3
      },
      custom_directories: {
        "app/services" => "Service objects",
        "app/forms" => "Form objects"
      },
      config_files: %w[
        config/application.rb
        config/puma.rb
        Gemfile
        Procfile
        docker-compose.yml
        .kamal/deploy.yml
      ]
    }
  end

  before do
    allow(described_class).to receive(:cached_context).and_return({
      conventions: conventions_data
    })
  end

  describe ".call" do
    it "returns conventions and architecture heading" do
      result = described_class.call
      text = result.content.first[:text]
      expect(text).to include("App Conventions & Architecture")
    end

    it "shows architecture patterns with human-readable labels" do
      result = described_class.call
      text = result.content.first[:text]
      expect(text).to include("Architecture")
      expect(text).to include("Hotwire (Turbo + Stimulus)")
      expect(text).to include("Service objects pattern")
      expect(text).to include("Dockerized")
    end

    it "shows detected patterns with human-readable labels" do
      result = described_class.call
      text = result.content.first[:text]
      expect(text).to include("Detected patterns")
      expect(text).to include("Single Table Inheritance (STI)")
      expect(text).to include("Polymorphic associations")
      expect(text).to include("Soft deletes")
    end

    it "shows directory structure with file counts" do
      result = described_class.call
      text = result.content.first[:text]
      expect(text).to include("Directory structure")
      expect(text).to include("app/models")
      expect(text).to include("12 files")
    end

    it "shows custom directories" do
      result = described_class.call
      text = result.content.first[:text]
      expect(text).to include("Custom Directories")
      expect(text).to include("app/services")
      expect(text).to include("Service objects")
    end

    it "shows notable config files, filtering obvious ones" do
      result = described_class.call
      text = result.content.first[:text]
      expect(text).to include("Notable config files")
      expect(text).to include("Procfile")
      expect(text).to include("docker-compose.yml")
      # Obvious config files should be filtered
      expect(text).not_to match(/^- `config\/application.rb`/)
      expect(text).not_to match(/^- `Gemfile`/)
    end

    it "generates a convention fingerprint summary" do
      result = described_class.call
      text = result.content.first[:text]
      expect(text).to include("Convention Fingerprint")
      expect(text).to include("This app uses")
    end
  end

  describe "edge cases" do
    it "handles missing conventions data" do
      allow(described_class).to receive(:cached_context).and_return({})
      result = described_class.call
      text = result.content.first[:text]
      expect(text).to include("not available")
    end

    it "handles conventions introspection error" do
      allow(described_class).to receive(:cached_context).and_return({
        conventions: { error: "introspection failed" }
      })
      result = described_class.call
      text = result.content.first[:text]
      expect(text).to include("failed")
      expect(text).to include("introspection failed")
    end

    it "handles empty architecture list" do
      conventions_data[:architecture] = []
      result = described_class.call
      text = result.content.first[:text]
      expect(text).not_to include("## Architecture")
    end

    it "handles empty patterns list" do
      conventions_data[:patterns] = []
      result = described_class.call
      text = result.content.first[:text]
      expect(text).not_to include("Detected patterns")
    end

    it "handles empty directory structure" do
      conventions_data[:directory_structure] = {}
      result = described_class.call
      text = result.content.first[:text]
      expect(text).not_to include("Directory structure")
    end

    it "handles nil config_files gracefully" do
      conventions_data[:config_files] = nil
      result = described_class.call
      text = result.content.first[:text]
      expect(text).to include("App Conventions & Architecture")
    end

    it "handles unknown architecture key with humanized fallback" do
      conventions_data[:architecture] = %w[custom_pattern]
      result = described_class.call
      text = result.content.first[:text]
      expect(text).to include("Custom pattern")
    end

    it "handles unknown pattern key with humanized fallback" do
      conventions_data[:patterns] = %w[custom_strategy]
      result = described_class.call
      text = result.content.first[:text]
      expect(text).to include("Custom strategy")
    end
  end
end

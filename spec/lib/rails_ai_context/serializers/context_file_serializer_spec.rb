# frozen_string_literal: true

require "spec_helper"

RSpec.describe RailsAiContext::Serializers::ContextFileSerializer do
  let(:context) { RailsAiContext.introspect }

  describe "#call" do
    it "writes files for all formats" do
      Dir.mktmpdir do |dir|
        allow(RailsAiContext.configuration).to receive(:output_dir_for).and_return(dir)
        serializer = described_class.new(context, format: :all)
        files = serializer.call
        expect(files.size).to eq(5)
      end
    end

    it "writes a single format" do
      Dir.mktmpdir do |dir|
        allow(RailsAiContext.configuration).to receive(:output_dir_for).and_return(dir)
        serializer = described_class.new(context, format: :claude)
        files = serializer.call
        expect(files.size).to eq(1)
        expect(File.read(files.first)).to include("Claude Code")
      end
    end

    it "dispatches cursor format to RulesSerializer" do
      Dir.mktmpdir do |dir|
        allow(RailsAiContext.configuration).to receive(:output_dir_for).and_return(dir)
        serializer = described_class.new(context, format: :cursor)
        files = serializer.call
        expect(File.read(files.first)).to include("Project Rules")
      end
    end

    it "raises for unknown format" do
      Dir.mktmpdir do |dir|
        allow(RailsAiContext.configuration).to receive(:output_dir_for).and_return(dir)
        serializer = described_class.new(context, format: :bogus)
        expect { serializer.call }.to raise_error(ArgumentError, /Unknown format/)
      end
    end
  end
end

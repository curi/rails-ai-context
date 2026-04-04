# frozen_string_literal: true

require "spec_helper"

RSpec.describe "MarkdownSerializer escape_markdown" do
  let(:serializer) { RailsAiContext::Serializers::MarkdownSerializer.new({}) }

  it "escapes asterisks" do
    expect(serializer.send(:escape_markdown, "*bold*")).to eq("\\*bold\\*")
  end

  it "escapes underscores" do
    expect(serializer.send(:escape_markdown, "_italic_")).to eq("\\_italic\\_")
  end

  it "escapes backticks" do
    expect(serializer.send(:escape_markdown, "`code`")).to eq("\\`code\\`")
  end

  it "escapes brackets and parens" do
    expect(serializer.send(:escape_markdown, "[link](url)")).to eq("\\[link\\]\\(url\\)")
  end

  it "escapes hash signs" do
    expect(serializer.send(:escape_markdown, "# heading")).to eq("\\# heading")
  end

  it "escapes pipes" do
    expect(serializer.send(:escape_markdown, "a|b")).to eq("a\\|b")
  end

  it "escapes tildes" do
    expect(serializer.send(:escape_markdown, "~strike~")).to eq("\\~strike\\~")
  end

  it "returns empty string for nil" do
    expect(serializer.send(:escape_markdown, nil)).to eq("")
  end

  it "passes through normal text unchanged" do
    expect(serializer.send(:escape_markdown, "UserModel")).to eq("UserModel")
  end

  it "handles mixed content" do
    expect(serializer.send(:escape_markdown, "my_*special*_gem")).to eq("my\\_\\*special\\*\\_gem")
  end

  it "converts non-strings to string first" do
    expect(serializer.send(:escape_markdown, 42)).to eq("42")
  end
end

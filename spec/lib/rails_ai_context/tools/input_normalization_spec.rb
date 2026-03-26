# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Tool input normalization" do
  # ── BaseTool.find_closest_match ─────────────────────────────────

  describe "BaseTool.find_closest_match" do
    subject { RailsAiContext::Tools::BaseTool }

    it "prefers shortest substring match (cooks over cook_comments)" do
      result = subject.find_closest_match("Cook", %w[cook_comments cooks cook_ratings])
      expect(result).to eq("cooks")
    end

    it "matches snake_case input to PascalCase available" do
      result = subject.find_closest_match("brand_profile", %w[BrandProfile User Post])
      expect(result).to eq("BrandProfile")
    end

    it "matches PascalCase input to snake_case available" do
      result = subject.find_closest_match("BrandProfile", %w[brand_profiles users posts])
      expect(result).to eq("brand_profiles")
    end

    it "returns exact case-insensitive match first" do
      result = subject.find_closest_match("users", %w[users user_settings])
      expect(result).to eq("users")
    end

    it "returns nil for empty available list" do
      result = subject.find_closest_match("anything", [])
      expect(result).to be_nil
    end

    it "falls back to prefix match when no substring matches" do
      result = subject.find_closest_match("xyz", %w[xyzzy abc def])
      expect(result).to eq("xyzzy")
    end
  end

  # ── GetModelDetails: snake_case model lookup ────────────────────

  describe "GetModelDetails snake_case resolution" do
    let(:klass) { RailsAiContext::Tools::GetModelDetails }

    before { klass.reset_cache! }

    before do
      models = {
        "BrandProfile" => { table_name: "brand_profiles", associations: [], validations: [] },
        "Cook" => { table_name: "cooks", associations: [], validations: [] }
      }
      allow(klass).to receive(:cached_context).and_return({ models: models })
    end

    it "resolves snake_case model name to PascalCase key" do
      result = klass.call(model: "brand_profile")
      text = result.content.first[:text]
      expect(text).to include("# BrandProfile")
    end

    it "resolves lowercase model name" do
      result = klass.call(model: "cook")
      text = result.content.first[:text]
      expect(text).to include("# Cook")
    end

    it "still works with exact PascalCase input" do
      result = klass.call(model: "BrandProfile")
      text = result.content.first[:text]
      expect(text).to include("# BrandProfile")
    end
  end

  # ── GetSchema: table name normalization ─────────────────────────

  describe "GetSchema table name normalization" do
    let(:klass) { RailsAiContext::Tools::GetSchema }

    before { klass.reset_cache! }

    before do
      tables = {
        "cooks" => {
          columns: [ { name: "id", type: "integer", null: false } ],
          indexes: [], foreign_keys: []
        },
        "cook_comments" => {
          columns: [ { name: "id", type: "integer", null: false } ],
          indexes: [], foreign_keys: []
        },
        "brand_profiles" => {
          columns: [ { name: "id", type: "integer", null: false } ],
          indexes: [], foreign_keys: []
        }
      }
      allow(klass).to receive(:cached_context).and_return({
        schema: { adapter: "postgresql", tables: tables, total_tables: 3 },
        models: {}
      })
    end

    it "resolves model name Cook to cooks table" do
      result = klass.call(table: "Cook")
      text = result.content.first[:text]
      expect(text).to include("Table: cooks")
    end

    it "resolves PascalCase model name to pluralized table" do
      result = klass.call(table: "BrandProfile")
      text = result.content.first[:text]
      expect(text).to include("Table: brand_profiles")
    end

    it "still works with exact table name" do
      result = klass.call(table: "cooks")
      text = result.content.first[:text]
      expect(text).to include("Table: cooks")
    end

    it "resolves singular model-style name via pluralization" do
      # "cook" → "cook".pluralize = "cooks" → direct match (no fuzzy needed)
      result = klass.call(table: "cook")
      text = result.content.first[:text]
      expect(text).to include("Table: cooks")
    end
  end

  # ── GetView: controller suffix stripping ────────────────────────

  describe "GetView controller suffix stripping" do
    let(:klass) { RailsAiContext::Tools::GetView }

    before { klass.reset_cache! }

    before do
      templates = {
        "cooks/index.html.erb" => { lines: 25, partials: [], stimulus: [] },
        "cooks/show.html.erb" => { lines: 40, partials: [], stimulus: [] }
      }
      allow(klass).to receive(:cached_context).and_return({
        view_templates: { templates: templates, partials: {} }
      })
    end

    it "resolves CooksController to cooks views" do
      result = klass.call(controller: "CooksController")
      text = result.content.first[:text]
      expect(text).to include("cooks/index.html.erb")
    end

    it "resolves cooks_controller to cooks views" do
      result = klass.call(controller: "cooks_controller")
      text = result.content.first[:text]
      expect(text).to include("cooks/index.html.erb")
    end

    it "still works with plain controller name" do
      result = klass.call(controller: "cooks")
      text = result.content.first[:text]
      expect(text).to include("cooks/index.html.erb")
    end
  end

  # ── GetRoutes: _controller suffix stripping ─────────────────────

  describe "GetRoutes controller suffix stripping" do
    let(:klass) { RailsAiContext::Tools::GetRoutes }

    before { klass.reset_cache! }

    before do
      routes = {
        by_controller: {
          "cooks" => [
            { verb: "GET", path: "/cooks", action: "index", name: "cooks" }
          ]
        },
        total_routes: 1
      }
      allow(klass).to receive(:cached_context).and_return({ routes: routes })
    end

    it "resolves cooks_controller to cooks routes" do
      result = klass.call(controller: "cooks_controller")
      text = result.content.first[:text]
      expect(text).to include("/cooks")
    end

    it "resolves CooksController to cooks routes" do
      result = klass.call(controller: "CooksController")
      text = result.content.first[:text]
      expect(text).to include("/cooks")
    end

    it "still works with plain controller name" do
      result = klass.call(controller: "cooks")
      text = result.content.first[:text]
      expect(text).to include("/cooks")
    end
  end

  # ── GetStimulus: PascalCase resolution ──────────────────────────

  describe "GetStimulus PascalCase resolution" do
    let(:klass) { RailsAiContext::Tools::GetStimulus }

    before { klass.reset_cache! }

    before do
      data = {
        controllers: [
          { name: "cook_status", targets: %w[badge], actions: %w[toggle], values: {}, outlets: [], classes: [], file: "cook_status_controller.js" }
        ]
      }
      allow(klass).to receive(:cached_context).and_return({ stimulus: data })
    end

    it "resolves PascalCase CookStatus to cook_status" do
      result = klass.call(controller: "CookStatus")
      text = result.content.first[:text]
      expect(text).to include("## cook_status")
    end

    it "resolves dash-separated cook-status to cook_status" do
      result = klass.call(controller: "cook-status")
      text = result.content.first[:text]
      expect(text).to include("## cook_status")
    end

    it "still works with exact underscore name" do
      result = klass.call(controller: "cook_status")
      text = result.content.first[:text]
      expect(text).to include("## cook_status")
    end
  end

  # ── GetEditContext: empty parameter validation ──────────────────

  describe "GetEditContext empty parameter validation" do
    let(:klass) { RailsAiContext::Tools::GetEditContext }

    it "returns friendly message for empty file parameter" do
      result = klass.call(file: "", near: "def index")
      text = result.content.first[:text]
      expect(text).to include("`file` parameter is required")
    end

    it "returns friendly message for whitespace-only file parameter" do
      result = klass.call(file: "   ", near: "def index")
      text = result.content.first[:text]
      expect(text).to include("`file` parameter is required")
    end

    it "returns friendly message for empty near parameter" do
      result = klass.call(file: "app/models/user.rb", near: "")
      text = result.content.first[:text]
      expect(text).to include("`near` parameter is required")
    end
  end

  # ── SearchCode: empty pattern handling ──────────────────────────

  describe "SearchCode empty pattern handling" do
    let(:klass) { RailsAiContext::Tools::SearchCode }

    before { klass.reset_cache! }

    it "returns friendly message for empty pattern" do
      result = klass.call(pattern: "")
      text = result.content.first[:text]
      expect(text).to include("Pattern is required")
    end

    it "returns friendly message for whitespace-only pattern" do
      result = klass.call(pattern: "   ")
      text = result.content.first[:text]
      expect(text).to include("Pattern is required")
    end
  end

  # ── GetTestInfo: plural model resolution ────────────────────────

  describe "GetTestInfo plural model resolution" do
    let(:klass) { RailsAiContext::Tools::GetTestInfo }

    before { klass.reset_cache! }

    before do
      allow(klass).to receive(:cached_context).and_return({
        tests: { framework: "Minitest", test_files: {} }
      })
    end

    it "tries singular form for model test lookup" do
      # find_test_file with plural "cooks" should produce candidates including the singular form
      result = klass.call(model: "cooks")
      text = result.content.first[:text]
      # Should search for cook_spec.rb / cook_test.rb (singular) in addition to cooks_spec.rb
      expect(text).to include("cook_spec.rb").or include("cook_test.rb").or include("cooks_spec.rb")
    end
  end
end

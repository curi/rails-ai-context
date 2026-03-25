# frozen_string_literal: true

module RailsAiContext
  # Generates a shareable AI readiness scorecard for the app.
  # Shows what AI knows WITH the gem vs what it would miss WITHOUT it.
  class Scorecard
    attr_reader :app

    def initialize(app = nil)
      @app = app || Rails.application
    end

    def generate
      context = RailsAiContext.introspect

      {
        app_name: context[:app_name] || app.class.module_parent_name,
        rails_version: context[:rails_version],
        ruby_version: context[:ruby_version],
        stats: compute_stats(context),
        scores: compute_scores(context),
        blind_spots: detect_blind_spots(context),
        token_comparison: estimate_tokens(context),
        recommendations: [],
        overall_score: 0
      }.tap do |r|
        r[:overall_score] = compute_overall(r[:scores])
        r[:recommendations] = build_recommendations(r[:scores], context)
      end
    end

    def render(result)
      lines = []
      name = result[:app_name]
      score = result[:overall_score]

      lines << ""
      lines << "  ┌#{'─' * 52}┐"
      lines << "  │ 🏆 AI Readiness Scorecard — #{name.to_s.ljust(22)} │"
      lines << "  └#{'─' * 52}┘"
      lines << ""

      # Stats bar
      s = result[:stats]
      lines << "  #{s[:models]} models │ #{s[:controllers]} controllers │ #{s[:routes]} routes │ #{s[:tables]} tables"
      lines << "  Rails #{result[:rails_version]} │ Ruby #{result[:ruby_version]}"
      lines << ""

      # Score bars
      result[:scores].each do |category, data|
        bar = score_bar(data[:score])
        lines << "  #{category.ljust(22)} #{bar}  #{data[:score]}%"
        lines << "  #{' ' * 22} #{data[:detail]}" if data[:detail]
      end
      lines << ""

      # Overall
      grade = case score
      when 90..100 then "EXCELLENT"
      when 75..89  then "GOOD"
      when 60..74  then "FAIR"
      else "NEEDS WORK"
      end
      lines << "  Overall: #{score}/100 — #{grade}"
      lines << ""

      # Blind spots — what AI would get wrong WITHOUT this gem
      if result[:blind_spots].any?
        lines << "  Without rails-ai-context, AI would:"
        result[:blind_spots].each { |b| lines << "  ✗ #{b}" }
        lines << ""
      end

      # Token comparison
      tc = result[:token_comparison]
      lines << "  Token usage:  Without gem: ~#{tc[:without]} tokens  │  With gem: ~#{tc[:with]} tokens (#{tc[:savings]}% saved)"
      lines << ""

      # Recommendations to reach 100
      if result[:recommendations].any? && score < 100
        lines << "  To reach 100%:"
        result[:recommendations].each { |r| lines << "  → #{r}" }
        lines << ""
      end

      # Share line
      lines << "  Share: \"My Rails app scores #{score}/100 on AI readiness 🏆 #railsaicontext\""
      lines << ""

      lines.join("\n")
    end

    private

    def compute_stats(ctx)
      {
        models: ctx[:models]&.size || 0,
        controllers: ctx.dig(:controllers, :controllers)&.size || 0,
        routes: ctx.dig(:routes, :total_routes) || 0,
        tables: ctx.dig(:schema, :tables)&.size || 0,
        jobs: ctx.dig(:jobs, :jobs)&.size || 0,
        views: Dir.glob(File.join(app.root, "app/views/**/*.erb")).size
      }
    end

    def compute_scores(ctx)
      scores = {}

      # Context Coverage — how much of the app is introspectable
      total_introspectors = RailsAiContext.configuration.introspectors.size
      working = ctx.count { |_k, v| v.is_a?(Hash) && !v[:error] }
      scores["Context Coverage"] = {
        score: total_introspectors > 0 ? ((working.to_f / total_introspectors) * 100).round : 0,
        detail: "#{working}/#{total_introspectors} introspectors returning data"
      }

      # Schema Intelligence — FK indexes + defaults coverage
      tables = ctx.dig(:schema, :tables) || {}
      fk_cols = 0; fk_indexed = 0
      tables.each_value do |t|
        (t[:columns] || []).each do |c|
          next unless c[:name].end_with?("_id")
          fk_cols += 1
          indexed = (t[:indexes] || []).any? { |i| Array(i[:columns]).first == c[:name] }
          fk_indexed += 1 if indexed
        end
      end
      schema_score = fk_cols > 0 ? ((fk_indexed.to_f / fk_cols) * 100).round : 100
      schema_detail = fk_cols > 0 ? "#{fk_indexed}/#{fk_cols} foreign keys indexed" : "no foreign keys to index"
      @schema_tips = []
      @schema_tips << "add indexes to FK columns" if fk_indexed < fk_cols
      scores["Schema Intelligence"] = { score: schema_score, detail: "#{tables.size} tables, #{schema_detail}" }

      # Model Depth — only checks associations + validations (every model should have these)
      models = ctx[:models] || {}
      model_depth_total = 0
      model_depth_filled = 0
      models.each_value do |data|
        next if data[:error]
        # Every model should have at least associations OR validations
        has_assoc = (data[:associations].is_a?(Array) && data[:associations].any?) ||
                    (data[:associations].is_a?(Hash) && data[:associations].any?)
        has_val = (data[:validations].is_a?(Array) && data[:validations].any?) ||
                  (data[:validations].is_a?(Hash) && data[:validations].any?)
        model_depth_total += 1
        model_depth_filled += 1 if has_assoc || has_val
      end
      scores["Model Depth"] = {
        score: model_depth_total > 0 ? ((model_depth_filled.to_f / model_depth_total) * 100).round : 0,
        detail: "#{model_depth_filled}/#{models.size} models have associations or validations"
      }

      # Test Coverage Map
      test_dir = File.join(app.root, "test")
      spec_dir = File.join(app.root, "spec")
      test_count = Dir.glob(File.join(test_dir, "**/*_test.rb")).size + Dir.glob(File.join(spec_dir, "**/*_spec.rb")).size
      model_count = models.size
      test_score = model_count > 0 ? [ ((test_count.to_f / (model_count * 2)) * 100).round, 100 ].min : 0
      scores["Test Coverage Map"] = {
        score: test_score,
        detail: "#{test_count} test files across #{model_count} models"
      }

      # Validation Power — how many cross-layer checks are active
      has_prism = begin; require "prism"; true; rescue LoadError; false; end
      has_brakeman = begin; require "brakeman"; true; rescue LoadError; false; end
      checks_available = 9 # base semantic checks
      checks_available += 3 if has_prism # AST-based checks
      checks_available += 1 if has_brakeman # security scan
      max_checks = 13
      scores["Validation Power"] = {
        score: ((checks_available.to_f / max_checks) * 100).round,
        detail: "#{checks_available}/#{max_checks} checks active" +
                (has_prism ? "" : " (add Prism for AST checks)") +
                (has_brakeman ? ", Brakeman: ✓" : " (add Brakeman for security)")
      }

      # MCP Tools
      tool_count = RailsAiContext::Server::TOOLS.size
      skip_count = RailsAiContext.configuration.skip_tools.size
      active = tool_count - skip_count
      scores["MCP Tools"] = {
        score: ((active.to_f / tool_count) * 100).round,
        detail: "#{active}/#{tool_count} tools active"
      }

      scores
    end

    def detect_blind_spots(ctx)
      spots = []
      models = ctx[:models] || {}

      # Encrypted columns AI wouldn't know about
      encrypted = models.values.flat_map { |m| m[:encrypts] || [] }
      spots << "Miss #{encrypted.size} encrypted column(s) (#{encrypted.join(', ')})" if encrypted.any?

      # Concern methods AI wouldn't discover
      concern_methods = 0
      models.each_value do |data|
        excluded = RailsAiContext.configuration.excluded_concerns
        app_concerns = (data[:concerns] || []).reject do |c|
          %w[Kernel JSON PP Marshal MessagePack].include?(c) ||
            excluded.any? { |pattern| c.match?(pattern) }
        end
        concern_methods += app_concerns.size
      end
      spots << "Not know #{concern_methods} concern module(s) and their methods" if concern_methods > 0

      # Devise/framework methods it would try to call
      models.each do |name, data|
        framework_methods = (data[:class_methods] || []).count { |m|
          m.match?(/\A(find_for_|find_or_|devise_|new_with_session|http_auth|params_auth)/)
        }
        spots << "Show #{framework_methods} Devise framework methods on #{name} as if they were app code" if framework_methods > 5
      end

      # Callbacks it would miss
      callback_count = models.values.sum { |m| m[:callbacks]&.values&.flatten&.size || 0 }
      spots << "Miss #{callback_count} model callback(s) that trigger side effects" if callback_count > 0

      # Stimulus naming errors
      stimulus_dir = File.join(app.root, "app/javascript/controllers")
      if Dir.exist?(stimulus_dir)
        stim_count = Dir.glob(File.join(stimulus_dir, "**/*_controller.{js,ts}")).size
        spots << "Use underscores instead of dashes for #{stim_count} Stimulus controller(s) in HTML" if stim_count > 0
      end

      # Before filters it would miss
      app_ctrl = File.join(app.root, "app/controllers/application_controller.rb")
      if File.exist?(app_ctrl)
        content = File.read(app_ctrl) rescue ""
        filters = content.scan(/before_action\s+:(\w+)/).flatten
        spots << "Miss #{filters.size} before_action filter(s) from ApplicationController (#{filters.first(3).join(', ')})" if filters.any?
      end

      # Turbo Stream wiring it would break
      views_dir = File.join(app.root, "app/views")
      if Dir.exist?(views_dir)
        turbo_count = Dir.glob(File.join(views_dir, "**/*.erb")).count { |f|
          content = File.read(f) rescue ""
          content.include?("turbo_stream_from") || content.include?("turbo_frame_tag")
        }
        spots << "Break Turbo Stream/Frame wiring in #{turbo_count} view(s)" if turbo_count > 0
      end

      spots.first(8)
    end

    def build_recommendations(scores, ctx)
      recs = []

      scores.each do |category, data|
        next if data[:score] >= 100

        case category
        when "Schema Intelligence"
          # Find unindexed FK columns
          tables = ctx.dig(:schema, :tables) || {}
          tables.each do |table_name, t|
            (t[:columns] || []).each do |c|
              next unless c[:name].end_with?("_id")
              indexed = (t[:indexes] || []).any? { |i| Array(i[:columns]).first == c[:name] }
              recs << "Add index: `rails g migration AddIndexTo#{table_name.camelize} #{c[:name]}:index`" unless indexed
            end
          end
        when "Model Depth"
          models = ctx[:models] || {}
          models.each do |name, d|
            next if d[:error]
            has_assoc = d[:associations].is_a?(Array) ? d[:associations].any? : d[:associations]&.any?
            has_val = d[:validations].is_a?(Array) ? d[:validations].any? : d[:validations]&.any?
            recs << "#{name}: add validations (every model should validate something)" unless has_assoc || has_val
          end
        when "Test Coverage Map"
          recs << "Add more test files (target: 2x your model count)"
        when "Validation Power"
          recs << "Add `gem 'prism'` for AST-based semantic checks" unless data[:detail]&.include?("Prism") || data[:score] >= 100
          recs << "Add `gem 'brakeman'` for security scanning" unless data[:detail]&.include?("Brakeman: ✓")
        when "MCP Tools"
          recs << "Remove entries from config.skip_tools to activate all 25 tools" if data[:score] < 100
        end
      end

      recs.first(5)
    end

    def estimate_tokens(ctx)
      # Rough estimates based on typical file sizes
      models_count = ctx[:models]&.size || 0
      tables_count = ctx.dig(:schema, :tables)&.size || 0

      # Without gem: AI reads schema.rb + all model files + routes.rb + controller files
      without = (tables_count * 500) + (models_count * 800) + 2000 + (models_count * 600)

      # With gem: 1-2 MCP calls return the same info
      with = (tables_count * 50) + (models_count * 120) + 500

      savings = without > 0 ? (((without - with).to_f / without) * 100).round : 0

      {
        without: format_number(without),
        with: format_number(with),
        savings: savings
      }
    end

    def compute_overall(scores)
      return 0 if scores.empty?
      total = scores.values.sum { |s| s[:score] }
      (total.to_f / scores.size).round
    end

    def score_bar(score)
      filled = (score / 5.0).round
      empty = 20 - filled
      "█" * filled + "░" * empty
    end

    def format_number(n)
      n.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse
    end
  end
end

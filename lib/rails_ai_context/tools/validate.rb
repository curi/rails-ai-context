# frozen_string_literal: true

require "open3"

module RailsAiContext
  module Tools
    class Validate < BaseTool
      tool_name "rails_validate"
      description "Validate syntax of multiple files at once (Ruby, ERB, JavaScript). Replaces separate ruby -c, erb check, and node -c calls. Returns pass/fail for each file with error details."

      MAX_FILES = 20

      input_schema(
        properties: {
          files: {
            type: "array",
            items: { type: "string" },
            description: "File paths relative to Rails root (e.g. ['app/models/cook.rb', 'app/views/cooks/index.html.erb'])"
          }
        },
        required: %w[files]
      )

      annotations(read_only_hint: true, destructive_hint: false, idempotent_hint: true, open_world_hint: false)

      def self.call(files:, server_context: nil)
        if files.empty?
          return text_response("No files provided.")
        end

        if files.size > MAX_FILES
          return text_response("Too many files (#{files.size}). Maximum is #{MAX_FILES} per call.")
        end

        results = []
        passed = 0
        total = 0

        files.each do |file|
          full_path = Rails.root.join(file)

          # Path traversal protection
          unless File.exist?(full_path)
            results << "\u2717 #{file} \u2014 file not found"
            total += 1
            next
          end

          begin
            real = File.realpath(full_path)
            unless real.start_with?(File.realpath(Rails.root))
              results << "\u2717 #{file} \u2014 path not allowed (outside Rails root)"
              total += 1
              next
            end
          rescue Errno::ENOENT
            results << "\u2717 #{file} \u2014 file not found"
            total += 1
            next
          end

          total += 1

          if file.end_with?(".rb")
            ok, msg = validate_ruby(full_path)
          elsif file.end_with?(".html.erb") || file.end_with?(".erb")
            ok, msg = validate_erb(full_path)
          elsif file.end_with?(".js")
            ok, msg = validate_javascript(full_path)
          else
            results << "- #{file} \u2014 skipped (unsupported file type)"
            total -= 1
            next
          end

          if ok
            results << "\u2713 #{file} \u2014 syntax OK"
            passed += 1
          else
            results << "\u2717 #{file} \u2014 #{msg}"
          end
        end

        output = results.join("\n")
        output += "\n\n#{passed}/#{total} files passed"

        text_response(output)
      end

      # Validate Ruby syntax via `ruby -c` (no shell — uses Open3 array form)
      private_class_method def self.validate_ruby(full_path)
        result, status = Open3.capture2e("ruby", "-c", full_path.to_s)
        if status.success?
          [ true, nil ]
        else
          error = result.lines.reject { |l| l.strip.empty? }.first&.strip || "syntax error"
          error = error.sub(full_path.to_s, File.basename(full_path.to_s))
          [ false, error ]
        end
      end

      # Validate ERB syntax by compiling the template (no shell — uses Open3 array form)
      private_class_method def self.validate_erb(full_path)
        script = "require 'erb'; ERB.new(File.read(ARGV[0])).src"
        result, status = Open3.capture2e("ruby", "-e", script, full_path.to_s)
        if status.success?
          [ true, nil ]
        else
          error = result.lines.reject { |l| l.strip.empty? }.first&.strip || "ERB syntax error"
          [ false, error ]
        end
      end

      # Validate JavaScript syntax via `node -c` (no shell — uses Open3 array form)
      private_class_method def self.validate_javascript(full_path)
        @node_available = system("which", "node", out: File::NULL, err: File::NULL) if @node_available.nil?

        if @node_available
          result, status = Open3.capture2e("node", "-c", full_path.to_s)
          if status.success?
            [ true, nil ]
          else
            error = result.lines.reject { |l| l.strip.empty? }.first&.strip || "syntax error"
            error = error.sub(full_path.to_s, File.basename(full_path.to_s))
            [ false, error ]
          end
        else
          validate_javascript_fallback(full_path)
        end
      end

      # Basic JavaScript validation when node is not available.
      # Checks for unmatched braces, brackets, and parentheses.
      MAX_VALIDATE_FILE_SIZE = 2_000_000

      private_class_method def self.validate_javascript_fallback(full_path)
        return [ false, "file too large for basic validation" ] if File.size(full_path) > MAX_VALIDATE_FILE_SIZE
        content = File.read(full_path)
        stack = []
        openers = { "{" => "}", "[" => "]", "(" => ")" }
        closers = { "}" => "{", "]" => "[", ")" => "(" }
        in_string = nil
        in_line_comment = false
        in_block_comment = false
        prev_char = nil

        content.each_char.with_index do |char, i|
          if in_line_comment
            in_line_comment = false if char == "\n"
            prev_char = char
            next
          end

          if in_block_comment
            if prev_char == "*" && char == "/"
              in_block_comment = false
            end
            prev_char = char
            next
          end

          if in_string
            if char == in_string && prev_char != "\\"
              in_string = nil
            end
            prev_char = char
            next
          end

          case char
          when '"', "'", "`"
            in_string = char
          when "/"
            if prev_char == "/"
              in_line_comment = true
              stack.pop if stack.last == "/" # remove the first / we may have pushed
            end
          when "*"
            if prev_char == "/"
              in_block_comment = true
            end
          else
            if openers.key?(char)
              stack << char
            elsif closers.key?(char)
              if stack.empty? || stack.last != closers[char]
                line_num = content[0..i].count("\n") + 1
                return [ false, "line #{line_num}: unmatched '#{char}'" ]
              end
              stack.pop
            end
          end

          prev_char = char
        end

        if stack.empty?
          [ true, nil ]
        else
          [ false, "unmatched '#{stack.last}' (node not available, basic check only)" ]
        end
      end
    end
  end
end

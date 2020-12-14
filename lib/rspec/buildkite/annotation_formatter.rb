require "thread"

require "rspec/core"
require "rspec/buildkite/recolorizer"
require 'tty-command'

module RSpec::Buildkite
  # Create a Buildkite annotation for RSpec failures
  #
  # Help folks fix their builds as soon as possible when failures crop up by
  # calling out failures in an annotation, even while the build is still running.
  #
  # Uses a background Thread so we don't block the build.
  #
  class AnnotationFormatter
    RSpec::Core::Formatters.register self, :start, :example_failed

    def initialize(output)
      # We don't actually use this, but keep a reference anyway
      @output = output

      # Only setup if we're actually running on Buildkite
      if ENV["BUILDKITE"]
        @queue = Queue.new
        @thread = Thread.new(&method(:thread))
        at_exit { @queue.push(:close); @thread.join }
      end
    end

    def start(notification)
      if ENV["BUILDKITE"]
        puts "rspec-buildkite has started."
      end
    end

    def example_failed(notification)
      @queue.push(notification) if @queue
    end

    private

    def thread
      cmd = TTY::Command.new(printer: :quiet)
      while notification = @queue.pop
        break if notification == :close

        if notification
          begin
            args = [
              "buildkite-agent",
              "annotate",
              "--context", "rspec",
              "--style", "error",
              "--append",
              format_failure(notification),
              only_output_on_error: true
            ]
            cmd.run(*args)
          rescue TTY::Command::ExitError => e
            puts e.message
          rescue Interrupt
            break
          end
        end
      end
    end

    def format_failure(notification)
      build_url = ENV["BUILDKITE_BUILD_URL"].to_s
      job_id = ENV["BUILDKITE_JOB_ID"].to_s
      job_url = "#{build_url}##{job_id}"

      %{<details>\n} <<
      %{<summary>#{notification.description.encode(:xml => :text)}</summary>\n} <<
      %{<pre class="term">#{Recolorizer.recolorize(notification.colorized_message_lines.join("\n").encode(:xml => :text))}</pre>\n} <<
      format_rerun(notification) <<
      %{<p>in <a href=#{job_url.encode(:xml => :attr)}>Job ##{job_id.encode(:xml => :text)}</a></p>\n} <<
      %{</details>} <<
      %{\n\n\n}
    end

    def format_rerun(notification)
      %{<pre class="term">} <<
      %{<span class="term-fg31">rspec #{notification.example.location_rerun_argument.encode(:xml => :text)}</span>} <<
      %{ <span class="term-fg36"># #{notification.example.full_description.encode(:xml => :text)}</span>} <<
      %{</pre>\n}
    end
  end
end

# frozen_string_literal: true

require 'fugit'
require 'stagnum'


class Qron

  VERSION = '1.0.0'.freeze

  attr_reader :options
  attr_reader :tab, :thread, :started, :last_sec, :work_pool

  def initialize(opts={})

    @options = opts
    @booted = false

    start unless opts[:start] == false
  end

  def start

    @started = Time.now
    @last_sec = @started.to_i

    @work_pool ||=
      ::Stagnum::Pool.new(
        "qron-#{::Qron::VERSION}-pool", @options[:workers] || 3)

    @thread =
      ::Thread.new do
        ::Thread.current[:name] =
          @options[:thread_name] || "qron-#{::Qron::VERSION}-thread"
        loop do
          break if @started == nil
          now = Time.now
          next if now.to_i == @last_sec
          tick(now)
          sleep 0.7 + (0.5 * rand)
        end
      end

    # TODO rescue perform...
  end

  def stop

    @started = nil

    @thread.kill
    @thread = nil
  end

  def join

    @thread && @thread.join
  end

  # In some deployments, another thread ticks the qron instance. So #tick(now)
  # is a public method.
  #
  def tick(now)

    fetch_tab.each do |cron, command|

      do_perform(now, cron, command) if cron_match?(cron, now)
    end

    @last_sec = now.to_i
    @booted = true
  end

  def fetch_tab

    @tab ||= read_tab
  end

  protected

  def parse_special(line)

    line.start_with?(/@reboot\s/) ?
      [ '@reboot', line.split(/\s+/, 2).last ] :
      nil
  end

  def parse_cron(line, word_count)

    ll = line.split(/\s+/, word_count + 1)
    c, r = ::Fugit::Cron.parse(ll.take(word_count).join(' ')), ll.last

    c ? [ c, r] : nil
  end

  def read_tab

    t = @options[:crontab] || @options[:tab] || 'qrontab'

    return t if t.is_a?(::Array)

    File.readlines(t)
      .inject([]) { |a, l|

        l = l.strip

        next a if l == ''
        next a if l.start_with?('#')

        a << (
          parse_special(l) ||
          parse_cron(l, 7) || parse_cron(l, 6) || parse_cron(l, 5) ||
          fail(ArgumentError.new("could not parse >#{l}<"))) }
  end

  def cron_match?(cron, time)

    if cron == '@reboot'
      @booted == false
    else
      cron.match?(time)
    end
  end

  def do_perform(now, cron, command)

    @work_pool.enqueue(make_context(now, cron, command)) do |ctx|

      ::Kernel.eval("Proc.new { |ctx| #{command} }").call(ctx)
    end
  end

  def make_context(now, cron, command)

    { time: now, cron: cron, command: command }
  end
end


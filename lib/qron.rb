# frozen_string_literal: true

require 'fugit'
require 'stagnum'


class Qron

  VERSION = '1.0.0'.freeze

  attr_reader :options
  attr_reader :tab, :thread, :started, :last_sec, :work_pool
  attr_reader :listeners

  def initialize(opts={})

    @options = opts
    @options[:reload] = false unless opts.has_key?(:reload)

    @tab = nil
    @tab_mtime = Time.now

    @booted = false
    @listeners = []

    start unless opts[:start] == false
  end

  def start

    @started = Time.now
    @last_sec = @started.to_i

    @work_pool ||=
      Stagnum::Pool.new("qron-#{Qron::VERSION}-pool", @options[:workers] || 3)

    @thread =
      Thread.new do
        Thread.current[:name] =
          @options[:thread_name] || "qron-#{Qron::VERSION}-thread"
        loop do
          break if @started == nil
          now = Time.now
          next if now.to_i == @last_sec
          tick(now)
          sleep(determine_sleep_time)
        end
      end
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

      perform(now, cron, command) if cron_match?(cron, now)
    end

    @last_sec = now.to_i
    @booted = true
  end

  def fetch_tab

    return @tab if @tab && @options[:reload] == false

    t = @options[:crontab] || @options[:tab] || 'qrontab'
    m = mtime(t)

    @tab = nil if m > @tab_mtime
    @tab_mtime = m

    @tab ||= parse(t)
  end

  def on_tab_error(&block); @listeners << [ :on_tab_error, block ]; end
  #def on_tick_error(&block); @listeners << [ :on_tick_error, block ]; end
  def on_perform_error(&block); @listeners << [ :on_perform_error, block ]; end

  def on_error(&block)
    @listeners << [ :on_tab_error, block ]
    @listeners << [ :on_perform_error, block ]
  end

  def trigger_event(event_name, ctx)

    @listeners.each { |name, block| block.call(ctx) if name == event_name }
  end

  protected

  def mtime(t)

    if t.is_a?(String) && t.count("\n") < 1 && File.exist?(t)
      File.mtime(t)
    else
      Time.now
    end
  end

  def parse(t)

    case t
    when Array then parse_lines(t)
    when /\n/ then parse_lines(t.lines)
    when String then parse_file(t)
    else fail(ArgumentError.new("cannot parse instance of #{t.class}"))
    end

  rescue => err

    trigger_event(:on_tab_error, time: Time.now, error: err)

    []
  end

  def parse_file(path)

    parse_lines(File.readlines(path))
  end

  def parse_lines(ls)

    ls.map { |l| parse_line(l) }.compact
  end

  def parse_line(l)

    l = l.strip

    return nil if l == ''
    return nil if l.start_with?('#')

    parse_special(l) ||
    parse_cron(l, 7) || parse_cron(l, 6) || parse_cron(l, 5) ||
    fail(ArgumentError.new("could not parse >#{l}<"))
  end

  def parse_special(line)

    line.start_with?(/@reboot\s/) ?
      [ '@reboot', line.split(/\s+/, 2).last ] :
      nil
  end

  def parse_cron(line, word_count)

    ll = line.split(/\s+/, word_count + 1)
    c, r = Fugit::Cron.parse(ll.take(word_count).join(' ')), ll.last

    c ? [ c, r] : nil
  end

  def cron_match?(cron, time)

    if cron == '@reboot'
      @booted == false
    else
      cron.match?(time)
    end
  end

  def perform(now, cron, command)

    @work_pool.enqueue(make_context(now, cron, command)) do |ctx|

      Kernel.eval("Proc.new { |ctx| #{command} }").call(ctx)

    rescue => err

      trigger_event(:on_perform_error, time: Time.now, error: err)
    end
  end

  def make_context(now, cron, command)

    { time: now, cron: cron, command: command,
      qron: self }
  end

  def determine_sleep_time

    0.7 + (0.5 * rand)
  end
end


# Should it be part of fugit?
#
class Fugit::Cron

  def resolution

    seconds == [ 0 ] ? :minute : :second
  end
end


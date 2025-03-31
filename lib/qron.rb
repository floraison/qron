# frozen_string_literal: true

require 'fugit'
require 'stagnum'


class Qron

  VERSION = '1.0.0'.freeze

  attr_reader :options
  attr_reader :tab, :thread, :started, :work_pool
  attr_reader :tab_res, :tab_mtime
  attr_reader :listeners

  def initialize(opts={})

    @options = opts
    @options[:reload] = false unless opts.has_key?(:reload)

    @tab = nil
    @tab_res = nil
    @tab_mtime = Time.now

    @booted = false
    @listeners = []

    start unless opts[:start] == false
  end

  def start

    @started = Time.now

    @work_pool ||=
      Stagnum::Pool.new("qron-#{Qron::VERSION}-pool", @options[:workers] || 3)

    @thread =
      Thread.new do
        Thread.current[:name] =
          @options[:thread_name] || "qron-#{Qron::VERSION}-thread"
        loop do
          break if @started == nil
          now = Time.now
          tick(now)
          sleep(determine_sleep_time(now))
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

    fetch_tab

    @tab.each do |cron, command|

      perform(now, cron, command) if cron_match?(cron, now)
    end

    @booted = true

    trigger_event(:on_tick, time: now)
  end

  def fetch_tab

    return @tab if @tab && @options[:reload] == false

    t = @options[:crontab] || @options[:tab] || 'qrontab'
    m = mtime(t)

    if m > @tab_mtime
      @tab = nil
      @tab_tempo = nil
    end
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

  def on_tick(&block); @listeners << [ :on_tick, block ]; end

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

    parse_setting(l) ||
    parse_special(l) ||
    parse_cron(l, 7) || parse_cron(l, 6) || parse_cron(l, 5) ||
    fail(ArgumentError.new("could not parse }#{l}{"))
  end

  def parse_setting(line)

    m = line.match(/^([a-z][_0-9a-zA-Z]*)\s+=\s+(.+)$/)

    m ? [ 'setting', "ctx[:#{m[1]}] = #{m[2]}" ] : nil
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
    elsif cron.is_a?(Fugit::Cron)
      cron.match?(time)
    else
      false # well...
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

    ctx = { time: now, cron: cron, command: command, qron: self }

    @tab.each do |c, command|

      Kernel.eval("Proc.new { |ctx| #{command} }").call(ctx) if c == 'setting'
    end

    ctx
  end

  def determine_sleep_time(now)

    @tab_res ||=
      @tab.find { |c, _| c.is_a?(Fugit::Cron) && c.resolution == :second } ?
        :second : :minute

    res = @tab_res == :second ? 1.0 : 60.0

    res - (now.to_f % res) + 0.021
  end
end


# Should it be part of fugit?
#
class Fugit::Cron

  def resolution

    seconds == [ 0 ] ? :minute : :second
  end
end


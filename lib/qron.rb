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

    @tab ||= read_tab

    @tab.each do |cron, command|

      do_perform(now, cron, command) if cron_match?(cron, now)
    end

    @last_sec = now.to_i
    @booted = true
  end

  protected

  def read_tab

    t = @options[:crontab] || @options[:tab] || 'qrontab'

    return t if t.is_a?(Array)

    # TODO timezones

    File.readlines(t)
      .inject([]) { |a, l|

        l = l.strip

        next a if l == ''
        next a if l.start_with?('#')

        if l.start_with?(/@reboot\s/)
          a << [ '@reboot', l.split(/\s+/, 2).last ]
          next a
        end

        ll5 = l.split(/\s+/, 6)
        ll6 = ll5.pop.split(/\s+/, 2)
        ll5 = ll5.join(' ')
        ll6, r = *ll6
        c = Fugit::Cron.parse("#{ll5} #{ll6}")
        unless c
          c = Fugit::Cron.parse(ll5)
          r = "#{ll6} #{r}"
        end
        a << [ c, r ]

        a }
  end

  def cron_match?(cron, time)

    if cron == '@reboot'
      @booted == false
    else
      cron.match?(time)
    end
  end

  def do_perform(now, cron, command)

    @work_pool.enqueue({ time: now, cron: cron, command: command }) do |ctx|

      ::Kernel.eval("Proc.new { |ctx| #{command} }").call(ctx)
    end
  end
end


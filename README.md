
# qron

[![tests](https://github.com/floraison/qron/workflows/test/badge.svg)](https://github.com/floraison/qron/actions)
[![Gem Version](https://badge.fury.io/rb/qron.svg)](http://badge.fury.io/rb/qron)

Queue and cron.

A stupid Ruby cron thread that wakes up from time to time to perform according
to what's written in a crontab.

Given `etc/qrontab_dev`:
```ruby
  @reboot       p [ :hello, "just started" ]
  * * * * *     p [ :hello, :min, Time.now ]
  * * * * * *   p [ :hello, :sec, Time.now ]
```

and

```ruby
require 'qron'

q = Qron.new(tab: 'etc/qrontab_dev')
q.join
```

```
[:hello, :sec, 2025-03-23 15:39:56.558783631 +0900]
[:hello, :sec, 2025-03-23 15:39:57.368985197 +0900]
[:hello, :sec, 2025-03-23 15:39:58.308865845 +0900]
[:hello, :sec, 2025-03-23 15:39:59.209102149 +0900]
[:hello, :min, 2025-03-23 15:40:00.149162785 +0900]
[:hello, :sec, 2025-03-23 15:40:00.149290935 +0900]
[:hello, :sec, 2025-03-23 15:40:01.039228675 +0900]
(...)
```

Uses [fugit](https://github.com/floraison/fugit) for cron parsing and
[stagnum](https://github.com/floraison/stagnum) as its worker pool.

A little brother to [rufus-scheduler](https://github.com/jmettraux/rufus-scheduler).


### `reload: true`

Specifying `reload: true` when initializing tells the `Qron` instance to reload its crontab file at every tick.

(Qron ticks usually every minute, unless it has one or more second precision crons specified, in which case it ticks every second).

```ruby
require 'qron'

q = Qron.new(tab: 'etc/qrontab_dev', reload: true)
```

### Timezones

It's OK to use timezones in the qrontab file:
```ruby
  30 * * * *     Asia/Tokyo        p [ :tokyo, :min, Time.now ]
  30 4 1,15 * 5  Europe/Budapest   p [ :budapest, :min, Time.now ]
```


### "Settings"

A qrontab file accepts, cron and commands but also "settings" that set
variables in the context passed to commands:
```ruby
  #
  # settings

  a = 1 + 2
  b = Time.now

  #
  # actual crons

  * * * * * *  pp [ :ctx, ctx ]
```
where the puts might output something like:
```ruby
[ :ctx,
  { time: 'Time instance...',
    cron: 'Fugit::Cron instance...',
    command: 'pp [ :ctx, ctx ]',
    qron: 'The Qron instance...',
    a: 3,
    b: 'Time instance...' } ]
```

A context is instantied and prepare for each command when it triggers.


## LICENSE

MIT, see [LICENSE.txt](LICENSE.txt)



# qron

[![tests](https://github.com/floraison/qron/workflows/test/badge.svg)](https://github.com/floraison/qron/actions)
[![Gem Version](https://badge.fury.io/rb/qron.svg)](http://badge.fury.io/rb/qron)

Queue and cron.

A stupid Ruby cron thread that wakes up from time to time to perform according
to what's written in a crontab.

Given `etc/qrontab_dev`:
```
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

## LICENSE

MIT, see [LICENSE.txt](LICENSE.txt)


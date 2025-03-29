
#
# Testing qron
#
# Sun Mar 23 15:44:19 JST 2025
#


group Qron do

  test 'it schedules' do

    File.open('test/qrontab', 'wb') { |f|
      f.write(%{
* * * * * *  $seen = true
      }) }

    $seen = false

    q = Qron.new(tab: 'test/qrontab')

    sleep 2.1

    assert $seen, true

    q.stop

    sleep 1.4

    assert q.started, nil
  end

  test 'it schedules @reboot' do

    File.open('test/qrontab', 'wb') { |f|
      f.write(%{
@reboot  $booted = true
      }) }

    $booted = false

    q = Qron.new(tab: 'test/qrontab')

    sleep 2.1

    assert $booted, true

    q.stop
  end

  test 'it schedules with a timezone' do

    File.open('test/qrontab', 'wb') { |f|
      f.write(%{
* * * * *                    $a << 'five'
* * * * * *                  $a << 'six'
* * * * * Asia/Tokyo         $a << ctx[:cron].timezone.name
* * * * * * Europe/Budapest  $a << ctx[:cron].timezone.name
      }) }

    $a = []

    q = Qron.new(tab: 'test/qrontab')

    sleep 2.8

    assert $a.count { |e| e == 'six' } > 1
    assert $a.count { |e| e == 'Europe/Budapest' } > 1

    q.stop
  end

  group '#on_error' do

    test 'it catches errors in perform' do

      File.open('test/qrontab', 'wb') { |f|
        f.write(%{
* * * * * *  fail 'hard'
        }) }

      $errors = []

      q = Qron.new(tab: 'test/qrontab')
      q.on_error { |ctx| $errors << ctx }

      sleep 2.1

      assert $errors.count > 0

      q.stop
    end
  end

  group '#on_tab_error' do

    test 'it catches errors in tabs' do

      File.open('test/qrontab', 'wb') { |f|
        f.write(%{
* pure fail
        }) }

      $errors = []

      q = Qron.new(tab: 'test/qrontab')
      q.on_tab_error { |ctx| $errors << ctx }

      sleep 2.1

#pp $errors
      assert $errors.count > 0

      q.stop
    end
  end

  group 'reload' do

    test 'does not reload by default' do

      File.open('test/qrontab', 'wb') { |f|
        f.write(%{
          * * * * * *  $b << 'alpha'
        }) }

      $b = []

      q = Qron.new(tab: 'test/qrontab')

      sleep 2.1

      File.open('test/qrontab', 'wb') { |f|
        f.write(%{
          * * * * * *  $b << 'bravo'
        }) }

      sleep 2.1

      assert $b.count { |e| e == 'alpha' } > 1
      assert $b.count { |e| e == 'bravo' } < 1

      q.stop
    end

    test 'reloads if reload: true' do

      File.open('test/qrontab', 'wb') { |f|
        f.write(%{
          * * * * * *  $c << 'alpha'
        }) }

      $c = []

      q = Qron.new(tab: 'test/qrontab', reload: true)

      sleep 2.1

      File.open('test/qrontab', 'wb') { |f|
        f.write(%{
          * * * * * *  $c << 'bravo'
        }) }

      sleep 2.1

      assert $c.count { |e| e == 'alpha' } > 1
      assert $c.count { |e| e == 'bravo' } > 1

      q.stop
    end
  end

  group 'resolution' do

    test 'sleeps until the next :minute' do

      File.open('test/qrontab', 'wb') { |f|
        f.write(%{
          * * * * *  n = Time.now; $d << n - $t; $t = n
        }) }

      $t = Time.now
      $d = []
      ts = []

      q = Qron.new(tab: 'test/qrontab')
      q.on_tick { ts << Time.now.min }

      wait_until(timeout: 185) { $d.size >= 2 }

      assert q.tab_res, :minute
      assert ts.uniq.length == ts.length
    end

    test 'sleeps until the next :second' do

      File.open('test/qrontab', 'wb') { |f|
        f.write(%{
          * * * * * *  n = Time.now; $e << n - $t; $t = n
        }) }

      $t = Time.now
      $e = []
      ts = []

      q = Qron.new(tab: 'test/qrontab')
      q.on_tick { ts << Time.now.sec }

      wait_until { $e.size > 5 }

      assert q.tab_res, :second
      assert $e.all? { |e| e > 0.0 && e < 1.2 }
      assert ts.uniq.length == ts.length
    end
  end
end


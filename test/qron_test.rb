
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

    sleep 1.4

    assert q.started, nil
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

    sleep 1.4
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

      sleep 1.4

      assert q.started, nil
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

      sleep 1.4

      assert q.started, nil
    end
  end

  group 'reload' do

    test 'does not reload by default' do

      File.open('test/qrontab', 'wb') { |f|
        f.write(%{
          * * * * * *  $a << 'alpha'
        }) }

      $a = []

      q = Qron.new(tab: 'test/qrontab')

      sleep 2.1

      File.open('test/qrontab', 'wb') { |f|
        f.write(%{
          * * * * * *  $a << 'bravo'
        }) }

      sleep 2.1

      assert $a.count { |e| e == 'alpha' } > 1
      assert $a.count { |e| e == 'bravo' } < 1

      q.stop; sleep 1.4
    end

    test 'reloads if reload: true' do

      File.open('test/qrontab', 'wb') { |f|
        f.write(%{
          * * * * * *  $a << 'alpha'
        }) }

      $a = []

      q = Qron.new(tab: 'test/qrontab', reload: true)

      sleep 2.1

      File.open('test/qrontab', 'wb') { |f|
        f.write(%{
          * * * * * *  $a << 'bravo'
        }) }

      sleep 2.1

      assert $a.count { |e| e == 'alpha' } > 1
      assert $a.count { |e| e == 'bravo' } > 1

      q.stop; sleep 1.4
    end
  end
end


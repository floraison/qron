
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

    sleep 2.1

    assert $a.count { |e| e == 'six' } > 1
    assert $a.count { |e| e == 'Europe/Budapest' } > 1
  end
end


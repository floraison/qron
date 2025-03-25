
#
# Testing qron
#
# Sun Mar 23 15:44:19 JST 2025
#


group Qron do

  test 'it schedules' do

    File.open('test/qrontab', 'wb') do |f|
      f.write(%{
* * * * * *  $seen = true
      })

    end

    $seen = false

    q = Qron.new(tab: 'test/qrontab')

    sleep 2.1

    assert $seen, true

    q.stop

    sleep 1.4

    assert q.started, nil
  end
end


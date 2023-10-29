# frozen_string_literal: true

require 'json'
require 'minitest/autorun'

def parse_session(fields)
  {
    browser: fields[3].upcase!,
    time: fields[4].to_i,
    date: fields[5].strip!
  }
end

def user_key(fields)
  "#{fields[2]} #{fields[3]}"
end

def write_stats(file, user, sessions, last_session = false)
  browsers = []
  session_time_list = []
  dates = []
  sessions.each do |s|
    browsers << s[:browser]
    session_time_list << s[:time]
    dates << s[:date]
  end
  stats = {
    user => {
      sessionsCount: sessions.size,
      totalTime: "#{session_time_list.sum} min.",
      longestSession: "#{session_time_list.max} min.",
      browsers: browsers.sort!.join(', '),
      usedIE: browsers.any? { |browser| browser =~ /INTERNET EXPLORER/ },
      alwaysUsedChrome: browsers.all? { |browser| browser =~ /CHROME/ },
      dates: dates.sort!.reverse!
    }
  }.to_json
  file.write(last_session ? "#{stats[1..-2]}}," : "#{stats[1..-2]},")
end

def work(data = 'data.txt', disable_gc: false)
  puts 'Start work'
  GC.disable if disable_gc

  report = {}
  report[:totalUsers] = 0
  report[:totalSessions] = 0
  unique_browsers = Set.new
  current_user = nil
  user_sessions = []

  result_file = File.open('result.json', 'a')
  result_file.write('{"usersStats":{')

  File.foreach(data) do |line|
    cols = line.split(',')
    if cols[0] == 'user'
      write_stats(result_file, current_user, user_sessions) unless user_sessions == []
      user_sessions = []
      report[:totalUsers] += 1
      current_user = user_key(cols)
    elsif cols[0] == 'session'
      report[:totalSessions] += 1
      session = parse_session(cols)
      unique_browsers << session[:browser]
      user_sessions << session
    end
  end
  write_stats(result_file, current_user, user_sessions, true)

  report[:uniqueBrowsersCount] = unique_browsers.size
  report[:allBrowsers] = unique_browsers.to_a.sort!.join(',')
  result_file.write(report.to_json[1..].to_s)
  result_file.close

  puts format('MEMORY USAGE: %d MB', `ps -o rss= -p #{Process.pid}`.to_i / 1024)
end

class TestMe < Minitest::Test
  def setup
    File.write('result.json', '')
    File.write('data.txt',
'user,0,Leida,Cira,0
session,0,0,Safari 29,87,2016-10-23
session,0,1,Firefox 12,118,2017-02-27
session,0,2,Internet Explorer 28,31,2017-03-28
session,0,3,Internet Explorer 28,109,2016-09-15
session,0,4,Safari 39,104,2017-09-27
session,0,5,Internet Explorer 35,6,2016-09-01
user,1,Palmer,Katrina,65
session,1,0,Safari 17,12,2016-10-21
session,1,1,Firefox 32,3,2016-12-20
session,1,2,Chrome 6,59,2016-11-11
session,1,3,Internet Explorer 10,28,2017-04-29
session,1,4,Chrome 13,116,2016-12-28
user,2,Gregory,Santos,86
session,2,0,Chrome 35,6,2018-09-21
session,2,1,Safari 49,85,2017-05-22
session,2,2,Firefox 47,17,2018-02-02
session,2,3,Chrome 20,84,2016-11-25
')
  end

  def test_result
    work
    expected_result = JSON.parse('{"totalUsers":3,"uniqueBrowsersCount":14,"totalSessions":15,"allBrowsers":"CHROME 13,CHROME 20,CHROME 35,CHROME 6,FIREFOX 12,FIREFOX 32,FIREFOX 47,INTERNET EXPLORER 10,INTERNET EXPLORER 28,INTERNET EXPLORER 35,SAFARI 17,SAFARI 29,SAFARI 39,SAFARI 49","usersStats":{"Leida Cira":{"sessionsCount":6,"totalTime":"455 min.","longestSession":"118 min.","browsers":"FIREFOX 12, INTERNET EXPLORER 28, INTERNET EXPLORER 28, INTERNET EXPLORER 35, SAFARI 29, SAFARI 39","usedIE":true,"alwaysUsedChrome":false,"dates":["2017-09-27","2017-03-28","2017-02-27","2016-10-23","2016-09-15","2016-09-01"]},"Palmer Katrina":{"sessionsCount":5,"totalTime":"218 min.","longestSession":"116 min.","browsers":"CHROME 13, CHROME 6, FIREFOX 32, INTERNET EXPLORER 10, SAFARI 17","usedIE":true,"alwaysUsedChrome":false,"dates":["2017-04-29","2016-12-28","2016-12-20","2016-11-11","2016-10-21"]},"Gregory Santos":{"sessionsCount":4,"totalTime":"192 min.","longestSession":"85 min.","browsers":"CHROME 20, CHROME 35, FIREFOX 47, SAFARI 49","usedIE":false,"alwaysUsedChrome":false,"dates":["2018-09-21","2018-02-02","2017-05-22","2016-11-25"]}}}')
    assert_equal expected_result, JSON.parse(File.read('result.json'))
  end
end

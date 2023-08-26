#!/usr/bin/ruby

STDIN.each_with_index do |l, i|
  artist = l.split(/\|/)
  puts "INSERT INTO artist (id, name, rating, active) VALUES (#{i+1}, '#{artist[1]}', 0, true);"
  puts "INSERT INTO enroll (site_id, artist_id, userid, username, url, fee) VALUES (1, #{i+1}, '#{artist[0]}', '#{artist[1]}', '#{artist[2]}', 0);"
end

#---

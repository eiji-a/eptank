#!/usr/bin/ruby

STDIN.each_with_index do |l, i|
  a = l.chomp.split(/\|/)
  a[1] = if a[1] == '' then 'NULL' else a[1] end
  puts "INSERT INTO article (id, title, url, ext, nimage, optinfo, active, site_id, artist_id, dl_date) VALUES (#{a[0]}, '', '#{a[5]}', '#{a[7]}', #{a[8]}, '#{a[6]}', true, #{a[2]}, #{a[1]}, '#{a[9]}');"
end

#---

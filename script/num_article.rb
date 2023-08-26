#!/usr/bin/ruby

#puts "SZ: #{ARGV.size}"
if ARGV.size != 1
  STDERR.puts "USAGE: num_article.rb <artist list>"
  exit 1
end

@artist = Hash.new
File.foreach(ARGV[0]) do |l|
  #STDERR.puts "L:#{l}"
  artist = l.split('|')
  #STDERR.puts "A: #{artist[0]}  /  #{artist[1]}"
  @artist[artist[1]] = artist[0]
end

STDIN.each_with_index do |l, i|
  article = l.split("|")
  #STDERR.puts "ARTIST: #{@artist[article[1]]}/#{article[1]}"
  print "#{i+1}|#{@artist[article[1]]}|1|#{l}"
end

#---

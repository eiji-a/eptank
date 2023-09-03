!#/usr/bin/ruby

require 'fileutils'

Dir.glob("*.zip") do |zf|
  zfb = File.basename(zf, '.zip')
  puts "ZF: #{zfb}"
  FileUtils.move(zf, zfb + '.cbz')

end

#---

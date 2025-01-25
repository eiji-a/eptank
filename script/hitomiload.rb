!#/usr/bin/ruby
# hitomiload.rb: Book loader for hitomi.la site
#
# CREATE: 2025-01-25  E. Akagi
# UPDATE:

require 'socket'
require "open-uri"
require "rubygems"
require "fileutils"
require "selenium-webdriver"
require "sqlite3"

USAGE = "hitomiload.rb <URL> <author(MAG,ANTH,others)> [<skip>]"
DEBUG = true
TIMEOUT = 300
#UA = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/51.0.2704.103 Safari/537.36"
UA = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/115.0.0.0 Safari/537.36'

MAXTHREADS = 20
MAXWAIT = 3          # wait seconds for page navigation
PAGEWAIT = 0.3
RETRY = 10
TYPES = {
  "Doujinshi" => "DJ",
  "Artist CG" => "CG",
  "Manga"     => "CM",
#  "Imageset"  => "IM",
}
ZIP = "zip -r "

def init
  if ARGV.size < 2 || ARGV.size > 3
    STDERR.puts USAGE
    exit 1
  end

  @url = ARGV[0]
    if ARGV[1] == 'MAG'
    @author = '雑誌'
    @anthology = true
  elsif ARGV[1] == 'ANTH'
    @author = 'アンソロジー'
    @anthology = true
  else
    @author = ARGV[1]
    @anthology = false
  end
  
  @range = if ARGV.size == 3 then
    r = ARGV[2].split(/-/)
    r[0] = if r[0] != '' then r[0].to_i - 1 else 0 end
    r[1] = r[1].to_i - 1 if r[1] != nil
    r[0]..r[1]
  else
    0..nil
  end

  options = Selenium::WebDriver::Chrome::Options.new
  #Eoptions.add_argument('--headless')
  options.page_load_strategy = :eager
  #profile = Selenium::WebDriver::Chrome::Profile.new
  #profile['javascript.enabled'] = false
  @session = Selenium::WebDriver.for :chrome,options: options #, profile: profile
  #@session = Selenium::WebDriver.for :chrome
  @session.manage.window.maximize
  
end

def dl_page(purl, iurl, pfile)
  return true if File.exist?(pfile) && File.size(pfile) > 0

  #puts "IM(#{pfile}): #{iurl}"
  charset = nil
  succ = false
  RETRY.times do |r|
    begin
      body = URI.open(iurl, "User-Agent" => UA, :read_timeout => TIMEOUT, "Referer" => purl) do |f|
        charset = f.charset
        f.read
      end
      if body != "" && body != nil
        File.open(pfile, 'w') do |fp|
          fp.write(body)
        end
      end
      succ = true
    rescue => e
      STDERR.puts "LOAD ERROR: #{e}" if e.to_s !~ /Temporarily/
      succ = false
    end
    break if succ == true
  end
  succ
end


def dl_pages2(bookurl, dn, pages)
  succ = true
  pages.each do |p|
    s = dl_page(bookurl, p[0], p[1])
    if s == false
      succ = false
      break
    end
  end
  succ
end

def dl_pages(bookurl, dn, pages)
  #puts "Start Download .. "
  params = Queue.new
  ret = 0

  while ret < RETRY && Dir.glob("#{dn}/*").count < pages.size
    #puts "DL: #{Dir.glob("#{dn}/*").count} <-> #{pages.size} / #{ret}"
    pages.each do |p|
      params.push(p)
    end
    threads = Array.new
    MAXTHREADS.times do |i|
      threads << Thread.new do
        succ = true
        until params.empty?
          param = params.pop(true) rescue false
          if param
            s = dl_page(bookurl, param[0], param[1])
            if s == false
              succ = false
              break
            end
          end
          succ
        end
      end
    end
  
    threads.each(&:join)
    ret += 1
  end
  puts "DL: #{Dir.glob("#{dn}/*").count} <-> #{pages.size} / #{ret}"
  ret < RETRY
end

def dl_book(bookurl, title, type, url, npage)
  succ = true
  tp = TYPES[type]
  puts "IMGURL: #{url}/ #PAGE: #{npage} / TYPE: #{tp} / TITLE: #{title}"
  return succ if tp == nil
  dn = Time.now.strftime("%Y%m%d%H%M%S")
  pages = Array.new
  1.upto(npage) do |i|
    url2 = url + "##{i}"
    img = ""
    print "I(#{i}): #{url2}\r"
    RETRY.times do
      begin
        @session.navigate.to url2
        sleep PAGEWAIT
        img = @session.find_element(:xpath, '//*[@id="comicImages"]/picture/source').attribute('srcset')
        break
      rescue StandardError => e
        begin
          img = @session.find_element(:xpath, '//*[@id="comicImages"]/picture/img').attribute('src')
          break
        rescue StandardError => e
          next
        end
      end
    end
    pnum = sprintf("%04d", i)
    ext = img.split(/\./)[-1]
    pages << [img, "#{dn}/#{pnum}.#{ext}"]
  end

  FileUtils.mkdir(dn)
  succ = dl_pages(bookurl, dn, pages)

  if succ
    File.open("#{dn}/info.txt", 'w') do |fp|
      fp.puts "BOOK: #{bookurl}"
      fp.puts "TITLE: #{title}"
      fp.puts "TYPE: #{tp}"
      fp.puts "PAGE: #{npage}"
    end
    # create ZIP file
    title.gsub!("'", "’")
    zipname = "（#{@author}）[#{tp}]#{title}.cbz"
    zipname = "（#{@author}）[#{tp}]#{title}-#{dn}.cbz" if File.exist?(zipname)
    begin
      system("#{ZIP} '#{zipname}' #{dn} > /dev/null")
    rescue
      succ = false
    end
  else
    STDERR.puts "DL ERROR: #{title}/#{bookurl}"
  end
  FileUtils.rm_rf(dn)
  succ
end

def book(url, id)
  try = true
  while try do
    @session.navigate.to url
    sleep MAXWAIT

    button = @session.find_element(:xpath, '//*[@id="gallery-brand"]/a')
    title = button.text
    link = @session.find_element(:xpath, '//*[@id="read-online-button"]')
    imageurl = link.attribute('href')
    pages = @session.find_elements(:xpath, '/html/body/div[2]/div[2]/div[4]/div/ul[1]/li')
    type = @session.find_element(:xpath, '//*[@id="type"]/a').text

    anthology = false
    @session.find_elements(:xpath, '//*[@id="tags"]/li').each do |t|
      if t.text == 'Anthology'
        anthology = true
        break
      end
    end
    break if anthology

    #puts "LINK: #{imageurl}"
    #puts "TITLE:#{title}/URL:#{imageurl}/SZ:#{pages.size}/TP:#{type}"

    if title != nil && imageurl != nil && pages.size > 0 && type != nil && anthology == @anthology
      printf("%4d/%4d: ", id+1, @nbooks)
      succ = dl_book(url, title, type, imageurl, pages.size)
      try = false if succ == true
    end
  end

end


def main
  post_id = init

  # 初期ページ
  @session.navigate.to @url
  sleep MAXWAIT
  p = @session.find_elements(:xpath, "/html/body/div[2]/div[4]/ul/li/a")
  popt = "?page="
  if p.size == 0
    p = @session.find_elements(:xpath, "/html/body/div[1]/div[3]/ul/li/a")
    popt = "#"
  end
  pages = if p[-1] != nil then p[-1].text.to_i else 1 end
  puts "NPAGE: #{pages}"

  books = Array.new
  1.upto(pages) do |i|
    @session.navigate.to "#{@url}#{popt}#{i}"
    sleep MAXWAIT
  
    elements = @session.find_elements(:xpath, "/html/body/div[2]/div[5]/div/h1/a")
    elements.each do |e|
      url   = e.attribute('href')
      title = e.text
      books << [url, title]
      #puts "#{title}/#{url}"
    end
  end

  @nbooks = books.size
  puts "#BOOKS: #{@nbooks}"
  #books.shift(@skip)
  puts "RANGE: #{@range}/#{books[@range].size}"
  books[@range].each_with_index do |b, i|
    book(b[0], @range.begin + i)
  end


end

main


#---

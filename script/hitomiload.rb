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

USAGE = "hitomiload.rb <URL> <author(MAG,ANTH,others)> [<range(n-m)>]"
DEBUG = true

class BookLoader

  TYPES = {
    "Doujinshi" => "DJ",
    "Artist CG" => "CG",
    "Manga"     => "CM",
  #  "Imageset"  => "IM",
  }

  def initialize(browser, url, author, range = nil)
    @browser = browser
    @url = url
    @author = author
    @range = if range != nil then
      r = range.split(/-/)
      r[0] = if r[0] != '' then r[0].to_i - 1 else 0 end
      r[1] = r[1].to_i - 1 if r[1] != nil
      r[0]..r[1]
    else
      0..nil
    end
  end
  
  XPATH_BOOKS = "/html/body/div[2]/div[5]/div/h1/a"

  def download
    # 初期ページ
    navigate(@url)

    np, popt = get_pageinfo
    pages = if np[-1] != nil then np[-1].text.to_i else 1 end
    puts "NPAGE: #{pages}"

    books = Array.new
    1.upto(pages) do |i|
      navigate("#{@url}#{popt}#{i}")
  
      find_elements(XPATH_BOOKS).each do |e|
        url   = e.attribute('href')
        title = e.text
        books << [url, title]
      end
    end

    @nbook = books.size
    puts "#BOOKS: #{@nbook}"
    books[@range].each_with_index do |b, i|
      dl_book(b[0], @range.begin + i)
    end
  end

  #-----PREOTECTED METHODS for inheritance
  protected

  XPATH_NPAGE = "/html/body/div[2]/div[4]/ul/li/a"
  XPATH_NPAGE2 = "/html/body/div[1]/div[3]/ul/li/a"
  XPATH_TAGS = '//*[@id="tags"]/li'

  def get_pageinfo
    np = find_elements(XPATH_NPAGE)
    return np, '?page='
  end

  def target?
    anthology = false
    find_elements(XPATH_TAGS).each do |t|
      if t.text == 'Anthology'
        anthology = true
        break
      end
    end
    !anthology
  end

  #-----PRIVATE METHODS
  private

  RETRY = 10

  XPATH_BOOKTITLE = '//*[@id="gallery-brand"]/a'
  XPATH_IMGURL = '//*[@id="read-online-button"]'
  XPATH_BOOKPAGES = '/html/body/div[2]/div[2]/div[4]/div/ul[1]/li'
  XPATH_BOOKTYPE = '//*[@id="type"]/a'

  def dl_book(url, id)
    try = true
    while try do
      navigate(url)
  
      title = find_element(XPATH_BOOKTITLE).text
      imageurl = find_element(XPATH_IMGURL).attribute('href')
      npage = find_elements(XPATH_BOOKPAGES).size
      type = find_element(XPATH_BOOKTYPE).text
      #puts "TITLE:#{title}/URL:#{imageurl}/SZ:#{pages.size}/TP:#{type}"
  
      break if !target?
  
      next if title == nil || imageurl == nil || npage == 0 || type == nil

      tp = TYPES[type]
      if tp != nil
        printf("%4d/%4d: ", id+1, @nbook)
        puts "IMGURL: #{imageurl}/ #PAGE: #{npage} / TYPE: #{tp} / TITLE: #{title}"
        dn = Time.now.strftime("%Y%m%d%H%M%S")
        pages = read_pages(npage, imageurl, dn)
        succ = create_zip(url, title, tp, pages, dn)
        try = false if succ == true
      else
        try = false
      end
    end
  end
  
  XPATH_IMGURL1 = '//*[@id="comicImages"]/picture/source'
  XPATH_IMGURL2 = '//*[@id="comicImages"]/picture/img'
  PAGEWAIT = 0.2

  def read_pages(npage, url, dn)
    pages = Array.new
    1.upto(npage) do |i|
      url2 = url + "##{i}"
      img = ""
      print "I(#{i}): #{url2}\r"
      RETRY.times do
        begin
          navigate(url2, PAGEWAIT)
          img = find_element(XPATH_IMGURL1).attribute('srcset')
          break
        rescue StandardError => e
          begin
            img = find_element(XPATH_IMGURL2).attribute('src')
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
    pages
  end

  ZIP = "zip -r "

  def create_zip(bookurl, title, tp, pages, dn)  
    FileUtils.mkdir(dn)
    succ = dl_pages(bookurl, dn, pages)
  
    if succ
      File.open("#{dn}/info.txt", 'w') do |fp|
        fp.puts "BOOK: #{bookurl}"
        fp.puts "TITLE: #{title}"
        fp.puts "TYPE: #{tp}"
        fp.puts "PAGE: #{pages.size}"
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

  MAXTHREADS = 20

  def dl_pages(bookurl, dn, pages)
    #puts "Start Download .. "
    params = Queue.new
    ntry = 0
  
    while ntry < RETRY && Dir.glob("#{dn}/*").count < pages.size
      puts "DL: #{Dir.glob("#{dn}/*").count} <-> #{pages.size} / #{ntry}"
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
      ntry += 1
    end
    puts "DL: #{Dir.glob("#{dn}/*").count} <-> #{pages.size} / #{ntry}"
    ntry < RETRY
  end

  UA = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/115.0.0.0 Safari/537.36'
  #UA = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/51.0.2704.103 Safari/537.36"
  TIMEOUT = 300

  def dl_page(purl, iurl, pfile)
    return true if File.exist?(pfile) && File.size(pfile) > 0
  
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

  MAXWAIT = 3          # wait seconds for page navigation

  def navigate(url, wait = MAXWAIT)
    @browser.navigate.to url
    sleep wait
  end

  def find_elements(xpath)
    @browser.find_elements(:xpath, xpath)
  end

  def find_element(xpath)
    @browser.find_element(:xpath, xpath)
  end
end

#----- MAIN

def init
  if ARGV.size < 2 || ARGV.size > 3
    STDERR.puts USAGE
    exit 1
  end

  options = Selenium::WebDriver::Chrome::Options.new
  #Eoptions.add_argument('--headless')
  options.page_load_strategy = :eager
  #profile = Selenium::WebDriver::Chrome::Profile.new
  #profile['javascript.enabled'] = false
  @session = Selenium::WebDriver.for :chrome,options: options #, profile: profile
  #@session = Selenium::WebDriver.for :chrome
  @session.manage.window.maximize

  ARGV
end

def main
  info = init
  loader = BookLoader.new(@session, info[0], info[1], info[2])
  loader.download
end

main


#---

!#/usr/bin/ruby

require 'socket'
require "open-uri"
require "rubygems"
#require "nokogiri"
require "fileutils"
require "selenium-webdriver"
require "sqlite3"

USAGE = "hitomiload.rb <URL> <author(MAG,ANTH,others)> [<skip>]"
DEBUG = true
TIMEOUT = 300
#UA = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/51.0.2704.103 Safari/537.36"
UA = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/115.0.0.0 Safari/537.36'

MAXARTISTLINE = 25
MAXTHREADS = 20
MAXIMG = 1000
MAXPOST = 50
MAXPOSTARTIST = 2
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
  
  @skip = if ARGV.size == 3 then ARGV[2].to_i else 0 end

  options = Selenium::WebDriver::Chrome::Options.new
  #Eoptions.add_argument('--headless')
  options.page_load_strategy = :eager
  #profile = Selenium::WebDriver::Chrome::Profile.new
  #profile['javascript.enabled'] = false
  @session = Selenium::WebDriver.for :chrome,options: options #, profile: profile
  #@session = Selenium::WebDriver.for :chrome
  @session.manage.window.maximize
  

=begin
  # 「同意」ボタンを押す（特別な時だけ？）
  link = @session.find_element(:xpath, '//*[@id="js-privacy-policy-banner"]/div/div/button')
  link.click
  sleep MAXWAIT
  link = @session.find_element(:xpath, '/html/body/div[2]/div/div/div[3]/div[1]/a[2]')
  link.click
  sleep MAXWAIT
  
  # ログイン
  ele_user = @session.find_element(:xpath, '//*[@id="app-mount-point"]/div/div/div[3]/div[1]/div[2]/div/div/div/form/fieldset[1]/label/input')
  ele_user.send_keys(user[0])
  ele_pass = @session.find_element(:xpath, '//*[@id="app-mount-point"]/div/div/div[3]/div[1]/div[2]/div/div/div/form/fieldset[2]/label/input')
  ele_pass.send_keys(user[1])
  link = @session.find_element(:xpath, '//*[@id="app-mount-point"]/div/div/div[3]/div[1]/div[2]/div/div/div/form/button')
  link.click
  sleep 5

  # サイドメニューを消す
  #sleep 60
  #link = @session.find_element(:xpath, '/html/body/div[7]/div/div[2]/div/div[1]/div[1]/div/button')
  #link.click
  #sleep 5

  #uid = session.find_element(:xpath, '/html/body/span[1]')
  #STDERR.puts "USER ID: #{uid.tag_name}, #{uid.text}" if DEBUG

  @artists = Array.new
  post_id = ARGV[1]
  return post_id
=end
end

def create_db(dbfile)
  db = SQLite3::Database.new(dbfile)
  sql = <<-SQL
    CREATE TABLE pixivpost (
      post_id TEXT,
      artist_id TEXT,
      url TEXT,
      post_time TEXT,
      ext TEXT,
      nimage INT,
      dldate DATETIME DEFAULT CURRENT_TIMESTAMP
    );
    CREATE INDEX pixivpostindex on pixivpost (
      post_id
    );
    CREATE TABLE pixivartist (
      artist_id TEXT,
      artist_name TEXT,
      url TEXT,
      level_real INT,
      level_ps INT,
      anotherurl TEXT,
      fee INT,
      regdate DATETIME DEFAULT CURRENT_TIMESTAMP
    );
    CREATE INDEX pixivartistindex on pixivartist (
      artist_id
    );
  SQL
  db.execute(sql)

  db
end

def exist_post?(post_id)
  e = false
  begin
    sql = <<-SQL
      SELECT COUNT(post_id) FROM pixivpost WHERE post_id = ?;
    SQL
    row = @db.execute(sql, post_id)
    if row.size > 0 && row[0][0] == 1
      e = true
    else
      e = false
    end
  rescue => e
    STDERR.puts "DB ERROR: #{e}" if DEBUG
  end
  e
end

def regist_post(post_id, artist_id, url, post_time, ext, nimage)
  begin
    sql = <<-SQL
      INSERT INTO pixivpost (post_id, artist_id, url, post_time, ext, nimage)
      VALUES (?, ?, ?, ?, ?, ?);
    SQL
    @db.execute(sql, post_id, artist_id, url, post_time, ext, nimage)
  rescue => e
    STDERR.puts "REGIST POST ERROR: #{e}"
  end
end

def read_artist
  @artists = Hash.new
  begin
    sql = <<-SQL
      SELECT artist_id FROM pixivartist;
    SQL
    rows = @db.execute(sql)
    rows.each do |r|
      @artists[r[0]] = r[1]
    end
  rescue => e
    STDERR.puts "READ ARTIST ERROR: #{e}"
  end
end

def exist_artist?(artist_id)
  e = false
  begin
    sql = <<-SQL
      SELECT COUNT(artist_id) FROM pixivartist WHERE artist_id = ?;
    SQL
    row = @db.execute(sql, artist_id)
    STDERR.puts "ROW: #{row}, AID=#{artist_id}"
    e =  if row.size > 0 && row[0][0] == 1 then true else false end
  rescue => e
    STDERR.puts "DB ERROR (ARTIST): #{e}" if DEBUG
  end
  e
end

def update_db_artists(diff_artists)
  diff_artists.each do |k, v|
    begin
      if v == nil # nil は削除対象
        sql = <<-SQL
          DELETE FROM pixivartist WHERE artist_id = ?;
        SQL
        @db.execute(sql, k)
      else
        if exist_artist?(k) == false
          STDERR.puts "REGIST ARTIST: #{k}/#{v}" if DEBUG
          sql = <<-SQL
            INSERT INTO pixivartist (artist_id, artist_name, url)
            VALUES (?, ?, ?);
          SQL
          url = "#{PIXIVARTISTURL}#{k}"
          @db.execute(sql, k, v, url)
        end
      end
    rescue => e
      STDERR.puts "REGIST ARTIST ERROR: #{e}" if DEBUG
    end
  end
end

def open_db(dbfile)
  if File.exist?(dbfile)
    sql = <<-SQL
      SELECT COUNT(post_id) FROM pixivpost;
    SQL
    @db = SQLite3::Database.new(dbfile)
    begin
      res = @db.execute(sql)
    rescue => e
      STDERR.puts "SELECTED ERROR: #{e}" if DEBUG
      create_db(dbfile)
    end
  else
    puts "CREATE"
    @db = create_db(dbfile)
  end
  #e = exist_post?('1111')
  #STDERR.puts "POST 1111: #{e}" if DEBUG
end

def close_db
  @db.close
end

#-------------------
#  POST DOWNLOAD
#-------------------

def load_image(prefix, date, imgfile)
  url = "#{PIXIVIMGURL}#{date}#{imgfile}"
  STDERR.puts "URL: #{url}" if DEBUG
  charset = nil
  succ = false
  begin
    body = URI.open(url, "User-Agent" => UA, :read_timeout => TIMEOUT, "Referer" => PIXIVHOST) do |f|
      charset = f.charset
      f.read
    end
    fname = "#{prefix}-#{imgfile}"
    if body != ""
      File.open(fname, 'w') do |fp|
        fp.write(body)
      end
    end
    succ = true
  rescue => e
    STDERR.puts "LOAD ERROR: #{e}" if DEBUG
    succ = false
  end
  succ
end  

def load_page_sel(post_id)
  return 0 if exist_post?(post_id)

  # 対象ページへ遷移
  url = "https://www.pixiv.net/artworks/#{post_id}"
  @session.navigate.to url
  sleep 5
  element = nil
  artisturl = @session.find_element(:xpath, '//*[@id="root"]/div[2]/div/div[3]/div/div/div[1]/aside/section[1]/h2/div/div/a')
  artist_id = artisturl.attribute('href').split("/")[-1]
  begin
    begin
      # "すべて見る"ボタンをクリック
      link = @session.find_element(:xpath, '//*[@id="root"]/div[2]/div/div[3]/div/div/div[1]/main/section/div[1]/div/div[4]/div/div[2]/button/div[2]')
      link.click
      #sleep 5
      element = @session.find_element(:xpath, '//*[@id="root"]/div[2]/div/div[3]/div/div/div[1]/main/section/div[1]/div/figure/div[1]/div[2]/div[2]/a')
    rescue
      element = @session.find_element(:xpath, '//*[@id="root"]/div[2]/div/div[3]/div/div/div[1]/main/section/div[1]/div/figure/div[1]/div[1]/div/a')
    end
  rescue => e
    STDERR.puts "PAGE NOT IMAGE?: #{e}" if DEBUG
    return 0
  end

  html = element.attribute('href')
  STDERR.puts "HREF: #{html}" if DEBUG
  html =~ /img-original\/img(\/\d\d\d\d\/\d\d\/\d\d\/\d\d\/\d\d\/\d\d\/)#{post_id}_p\d+\.(\S+)$/
  date = $1
  ext  = $2

  pages = Array.new
  prefix = Time.now.strftime("%Y%m%d%H%M%S%L") + "-#{artist_id}"

  nimg = 0
  while nimg < MAXIMG do
    imgfile = "#{post_id}_p#{nimg}.#{ext}"
    break unless load_image(prefix, date, imgfile)
    nimg += 1
  end
  if nimg > 0
    regist_post(post_id, artist_id, url, date, ext, nimg)
  end
  nimg
end


def update_artists
  p = 1
  @session.navigate.to "#{PIXIVFOLLOWURL}?p=1"
  element = @session.find_element(:xpath, '//*[@id="root"]/div[2]/div/div[3]/div/div/div[2]/div[2]/div[2]/div/section/div[1]/div/div/div/span')
  nfollow = element.text.to_i
  STDERR.puts "FOLLOWS: #{nfollow}" if DEBUG

  read_artist
  return if (nfollow - @artists.size).abs < 20  #差が10未満なら許容する
  #return if nfollow == @artists.size

  curr_artists = Hash.new
  loop do # loop per following page
    begin
      MAXARTISTLINE.times do |al|
        begin
          artist = @session.find_element(:xpath, "//*[@id=\"root\"]/div[2]/div/div[3]/div/div/div[2]/div[2]/div[2]/div/section/div[2]/div[#{al+1}]/div/div[1]/div/a")
          artist_id = artist.attribute('href').split("/")[-1]
          artist_name = @session.find_element(:xpath, "//*[@id=\"root\"]/div[2]/div/div[3]/div/div/div[2]/div[2]/div[2]/div/section/div[2]/div[#{al+1}]/div/div[1]/div/div/div[1]/a").text

          curr_artists[artist_id] = artist_name
          STDERR.puts "ARTIST: #{artist_id} / #{artist_name} (#{p})" if DEBUG
        rescue => e
          STDERR.puts "MAXLINE: #{al} / #{e}" if DEBUG
          break
        end
      end
    rescue => e
      STDERR.puts "ARTIST LIST ERROR: #{e}" if DEBUG
    end

    nextbutton = @session.find_elements(:xpath, "//*[@id=\"root\"]/div[2]/div/div[3]/div/div/div[2]/nav/a")[-1]
    break if nextbutton.attribute('hidden') == 'true'
    nextbutton.click
    sleep MAXWAIT

  end

  diff_artists = Hash.new
  # フォロワーが増えていたら追加
  curr_artists.each do |a, n|
    STDERR.puts "EXIST ARTIST? #{@artists[a]}" if DEBUG
    next if @artists[a] != nil
    @artists[a] = n
    diff_artists[a] = n
    STDERR.puts "ADD ARTIST: #{a} / #{n}" if DEBUG
  end
  # フォロワーから削除されていたらDBも削除
  @artists.each do |a, n|
    next if curr_artists[a] != nil
    @artists.delete(a)
    diff_artists[a] = nil
    STDERR.puts "DELETE ARTIST: #{a} / #{n}"
  end

  update_db_artists(diff_artists)
end

def select_posts
  post_list = Array.new
  npost = 0
  artist_list = @artists.keys
  loop do
    break if npost >= MAXPOST
    artist_id = artist_list.sample
    next if artist_id == PIXIVOPEID # IDがPIXIV事務局ならスキップ

    STDERR.puts "ARTISTID: #{artist_id}" if DEBUG
    @session.navigate.to "#{PIXIVARTISTURL}#{artist_id}#{PIXIVARTISTOPT}"  # R-18のみ抽出
    #@session.navigate.to "#{PIXIVARTISTURL}#{artist_id}"
    sleep 5
=begin
    begin
      # "すべて見る"ボタンを押す
      link = @session.find_element(:xpath, '//*[@id="root"]/div[2]/div/div[3]/div/div/div[2]/div[3]/div/div/section/div[3]/a')
      link.click
      sleep 10
    rescue => e
      STDERR.puts "CLICK ERROR: #{e}"
    end
=end
    pcount = 0 # アーティスト毎の取得ポスト数
    loop do
      break if npost >= MAXPOST || pcount >= MAXPOSTARTIST
      PIXIVMAXPOST.times do |i|
        break if npost >= MAXPOST || pcount >= MAXPOSTARTIST
        begin
          element = @session.find_element(:xpath, "//*[@id=\"root\"]/div[2]/div/div[3]/div/div/div[2]/div[3]/div/div/section/div[3]/div/ul/li[#{i+1}]/div/div[1]/div/a")
          post_id = element.attribute('href').split("/")[-1]
          unless exist_post?(post_id)
            STDERR.puts "POSTID: #{post_id}/#{artist_id}"
            post_list << post_id
            npost += 1
            pcount += 1
          end
        rescue => e
          STDERR.puts "PAGEID: ELEMENT IS NIL: #{e}" if DEBUG
          STDERR.puts "ARTIST MAY NOT BE DISABLED: artist=#{artist_id}/post=#{post_id}" if post_id == nil
          pcount = MAXPOSTARTIST
        end
      end

      begin
        # アーティスト取得ポスト数に満たないなら次ページへ
        break if pcount >= MAXPOSTARTIST
        nextbutton = @session.find_elements(:xpath, "//*[@id=\"root\"]/div[2]/div/div[3]/div/div/div[2]/nav/a")[-1]
        break if nextbutton.attribute('hidden') == 'true'
        # 最終ページならbreak
        nextbutton.click
        sleep MAXWAIT
      rescue => e
        STDERR.puts "NEXT PAGE ERROR: #{e}" if DEBUG
      end
    end
  end

  post_list
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
=begin  
  begin
    dbfile = "/Volumes/Public/eimage/test.sqlite"
    if File.exist?(dbfile) == false
      STDERR.puts "DBFILE DOESN'T EXIST!: #{dbfile}"
      exit 1
    end
    #dbfile = "test.sqlite"

    open_db(dbfile)

    if post_id != nil
      nimage = load_page_sel(post_id)
      STDERR.puts "#IMAGE: #{nimage} images are downloaded."
    else
      update_artists
      posts = select_posts
      nimage = 0
      posts.each_with_index do |post_id, i|
        STDERR.print "(#{i+1}/#{posts.size}) POST #{post_id}: "
        nimg = load_page_sel(post_id)
        STDERR.puts "#{nimg} images are downloaded"
        nimage += nimg
      end
      STDERR.puts "#IMAGE: #{nimage} images are downloaded."
    end
  rescue => e
    STDERR.puts "ERROR: #{e}" if DEBUG
  ensure
    close_db
  end
=end


  # 初期ページ

  @session.navigate.to @url
  sleep MAXWAIT
  p = @session.find_elements(:xpath, "/html/body/div[2]/div[4]/ul/li/a")
  popt = "?page="
  if p.size == 0
    p = @session.find_elements(:xpath, "/html/body/div[1]/div[3]/ul/li/a")
    popt = "#"
  end
  puts "#{p.class}/#{p.size}"
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
  books.shift(@skip)
  books.each_with_index do |b, i|
    book(b[0], @skip+i)
  end


end

main


#---

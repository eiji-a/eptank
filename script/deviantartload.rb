!#/usr/bin/ruby
#
# 注意事項：スクレイピング対策がされているため、一旦Chromeからログインして記録を作っておく必要がある。
#          (1) 次のディレクトリを削除する（~/.config/google-chrome/Defaults）
#          (2) 一旦Chromeでログインする
#          (3) 本スクリプトを実行する。


require 'socket'
require 'open-uri'
require 'rubygems'
require 'fileutils'
require 'selenium-webdriver'
require 'mysql'

require_relative 'eptanklib'
require_relative 'deviantartlib'

USAGE = "deviantartload.rb <YAML config> [<post id>]"
DEBUG = true
TIMEOUT = 300
#UA = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/51.0.2704.103 Safari/537.36"
UA = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/115.0.0.0 Safari/537.36'

DEVIANTSITEID    = 3
DEVIANTHOST      = 'https://www.deviantart.com/'
DEVIANTLOGIN     = 'https://www.deviantart.com/users/login'
DEVIANTARTISTURL = DEVIANTHOST
DEVIANTARTISTOPT = '/gallery/all'
DEVIANTOPEID     = ''
DEVIANTMAXPOST   = 50
DEVIANTMAXPAGE   = 100
COOKIECOMMON = {:path=>"/", :domain=>".deviantart.com", :same_site=>"Lax"}
COOKIE = [
  # change
  {:name => 'td', :value => '7:872%3B12:876x927%3B20:880'},
  {:name => 'userinfo', :expires => '2023-10-10T10:43:45.260Z', :value => '__c147632684c4826e4c02%3B%7B%22username%22%3A%22redforest13%22%2C%22uniqueid%22%3A%2267b3c5eecc3191a595f1980d76444515%22%2C%22dvs9-1%22%3A1%2C%22ab%22%3A%22tao-fdt-1-a-6%7Ctao-aan-1-b-6%22%7D'},
  {:name => 'auth_secure', :value => '__9471423ee61667f006c5%3B%22085411209176d8455d64b69185e7737a%22', :http_only => false, :secure => false},
  {:name => 'auth', :value => '__e201fcc1a7e87114a15b%3B%223377b5317e0ca3a81b068f13b73b259f%22', :secure => false},
  {:name => 'pxcts', :value => '16dea05c-4fca-11ee-946d-d232b25d8db1'},
  {:name => '_px', :value => 'UGPjgZMsxNBVE+bR5COR8a0WQWPRLWVAPONL1U54Y0FrFk8rAAQlM/l0NHttz8H0pM5l++v6IBGkTaCLHPsVuA==:1000:HwiKs6HMMyUJH07W3kjQ/IiI20BTArX6FnQl9o9BewLHYoTgvcdq6os5Uqq4iIkEfwPGIV2te7iZBWI0pn6DJYtCnZ+dboDHnIq4xjYGdDvMjkBZHBWlPYb3xs7gcvvV198U5LQVtvV12C/Cj5sxP4/3KzLAsklFmkqeIYmWQKhmhc62njsMGz5lElKsGzZ+LhXgNnjdkYLMDcQ6s4YUic52L7zGQYjShj0npHP4j1oi+9lhNRuz/SlVlTAoIFmR8mtdvdEF08yFDBb3pfIe9Q=='},
  {:name => '_pxvid', :value => 'dd2e1e34-4fbb-11ee-b612-b266447164c3'},
]


MAXWAIT = 5          # wait seconds for page navigation

def init
  if ARGV.size != 1 && ARGV.size != 2
    STDERR.puts USAGE
    exit 1
  end

  $PARAM = load_config(ARGV[0])
  $DEVIANT = $PARAM['deviantart']

  @db = EpTank.new($PARAM['database'])
  @session = WebSession.new(WebSession::WITHSCR, $PARAM['chromeprofile'])
  
  # 初期ページ
  #COOKIE.each do |c|
  #  @session.add_cookie(c.merge(COOKIECOMMON))
  #end
  #@session.navigate(DEVIANTLOGIN)
  @session.navigate(DEVIANTHOST)
  #cookies = @session.all_cookies
  #STDERR.puts "COOKIE: #{cookies}"
  #cookies.each do |c|
  #  @session.add_cookie(c)
  #end
  sleep 20

  # 「同意」ボタンを押す（特別な時だけ？）
  #@session.click('//*[@id="js-privacy-policy-banner"]/div/div/button', 2)
  # 「サインイン」ボタンを押す
  #@session.click('/html/body/div[2]/div/div/div[3]/div[1]/a[2]', 2)

  # ログイン
  #@session.click('//*[@id="root"]/header/div[3]/a[2]', 3)
  #@session.send_keys($DEVIANT['id'], '//*[@id="username"]', 0)
  #@session.send_keys($DEVIANT['pw'], '//*[@id="password"]', 0)
  #@session.click('//*[@id="loginbutton"]', 3)

  #@session.all_cookies.each do |c|
  #  next if c['name'] != 'auth'
  #  STDERR.puts "AUTH: #{c}"
  #end

  # サイドメニューを消す
  #sleep 60
  #link = @session.find_element(:xpath, '/html/body/div[7]/div/div[2]/div/div[1]/div[1]/div/button')
  #link.click
  #sleep 5

  #uid = session.find_element(:xpath, '/html/body/span[1]')
  #STDERR.puts "USER ID: #{uid.tag_name}, #{uid.text}" if DEBUG

  return ARGV[1]
end

#-------------------
#  POST DOWNLOAD
#-------------------

def load_image(artist_id, prefix, date, imgfile, post_id)
  if File.exist?($PARAM['eptank']['dir']) == false
    STDERR.puts "DL DIR ISN'T EXIST: #{$PARAM['eptank']['dir']}"
    return false
  end
  url = "#{PIXIVIMGURL}#{date}#{imgfile}"
  STDERR.puts "URL: #{url}" if DEBUG
  charset = nil
  succ = false
  begin
    body = URI.open(url, "User-Agent" => UA, :read_timeout => TIMEOUT, "Referer" => DEVIANTHOST) do |f|
      charset = f.charset
      f.read
    end
    dldir = "#{$PARAM['eptank']['dir']}#{@artists[artist_id]}"
    if File.exist?(dldir) == false
      FileUtils.mkdir(dldir)
    end
    fname = "#{@artists[artist_id]}/#{prefix}-#{imgfile}"
    STDERR.puts "DL FILE: #{fname}" if DEBUG

    if body != ""
      File.open($PARAM['eptank']['dir'] + fname, 'w') do |fp|
        fp.write(body)
      end
    end
    @db.regist_image(fname, post_id, artist_id)
    succ = true
  rescue => e
    STDERR.puts "LOAD ERROR: #{e}" if DEBUG
    succ = false
  end
  succ
end  

def load_image2(url, prefix, artist_id, post_id)
  if File.exist?($PARAM['eptank']['dir']) == false
    STDERR.puts "DL DIR ISN'T EXIST: #{$PARAM['eptank']['dir']}"
    return false
  end
  charset = nil
  succ = false
  begin
    body = URI.open(url, "User-Agent" => UA, :read_timeout => TIMEOUT, "Referer" => DEVIANTHOST) do |f|
      charset = f.charset
      f.read
    end
    dldir = "#{$PARAM['eptank']['dir']}#{@artists[artist_id]}"
    if File.exist?(dldir) == false
      FileUtils.mkdir(dldir)
    end
    imgfile = url.split("/")[-1]
    imgfile = if imgfile =~ /\?/
      imgfile.split("?")[0]
    else
      imgfile
    end
    fname = "#{@artists[artist_id]}/#{prefix}-#{imgfile}"
    STDERR.puts "DL FILE: #{fname}" if DEBUG

    if body != ""
      File.open($PARAM['eptank']['dir'] + fname, 'w') do |fp|
        fp.write(body)
      end
    end
    @db.regist_image(fname, post_id, artist_id)
    succ = true
  rescue => e
    STDERR.puts "LOAD ERROR: #{e}" if DEBUG
    succ = false
  end
  succ
end  

def load_page_sel(purl)
  return 0 if @db.exist_post?(purl)

  artist_id, artist_nm, title, image_urls = getinfo_artwork(purl, @session)

  if @artists[artist_id] == nil
    @db.update_artists({artist_id => artist_nm})
    @artists[artist_id] = artist_nm
  end

  nimg = 0
  rc, post_id = @db.regist_post(DEVIANTSITEID, title, artist_id, purl, '', '', nimg)
  return 0 if rc == false

  prefix = Time.now.strftime("%Y%m%d%H%M%S%L") + "-#{artist_id}"
  image_urls.each do |u|
    next unless load_image2(u, prefix, artist_id, post_id)
    nimg += 1
  end

  if nimg > 0
    @db.update_post(purl, nimg)
    @db.commit
  else
    @db.rollback
  end
  nimg
end


def update_artists
  nfollow, artists, nextbutton = getinfo_following("#{PIXIVARTISTURL}#{$PARAM['pixiv']['user']}/following?p=1", @session)
  STDERR.puts "NFOLLOW/@ARTIST: #{nfollow}/#{@artists.size}" if DEBUG
  return if (nfollow - @artists.size).abs < 0  #差が10未満なら許容する

  curr_artists = artists
  page = 1

  while nextbutton != nil
    page += 1
    url = "#{PIXIVARTISTURL}#{$PARAM['pixiv']['user']}/following?p=#{page}"
    nfollow, artists, nextbutton = getinfo_following(url, @session)
    curr_artists.merge!(artists)
  end

  diff_artists = Hash.new
  # フォロワーが増えていたら追加
  curr_artists.each do |a, n|
    STDERR.puts "EXIST ARTIST? #{@artists[a]}" if DEBUG
    next if @artists[a] != nil
    @artists[a] = n
    diff_artists[a] = n
    STDERR.puts "ADD ARTIST: #{a} / #{n}"
  end
  # フォロワーから削除されていたらDBも削除
  @artists.each do |a, n|
    next if curr_artists[a] != nil
    @artists.delete(a)
    diff_artists[a] = nil
    STDERR.puts "DELETE ARTIST: #{a} / #{n}"
  end

  @db.update_artists(diff_artists)
end

def select_news(urls, np)
  plist = Array.new
  urls.each do |u|
    break if np == 0
    unless @db.exist_post?(u)
      STDERR.puts "POST URL: #{u}"
      plist << u  # DeviantArtではページのURLをそのまま返す
      np -= 1
    end
  end
  plist
end

def select_posts
  post_list = Array.new
  npost = 0

  @artists.keys.shuffle.each do |artist_id|
    #next if artist_id == DEVIANTOPEID # IDがPIXIV事務局ならスキップ
    ex, a = @db.exist_artist?(artist_id)
    if ex == false
      STDERR.puts "ARTIST ISN'T REGISTERED: #{artist_id}"
      next
    end
    break if npost >= $DEVIANT['maxpost']
    pcount = 0
    page = 1
    STDERR.puts "ARTISTID: #{artist_id}" if DEBUG


    article_urls, nextbutton = getinfo_illustration("#{DEVIANTARTISTURL}#{artist_id}#{DEVIANTARTISTOPT}?page=#{page}", @session)
    STDERR.puts "NARTICLES: #{article_urls.size}"

    plist = select_news(article_urls, [$DEVIANT['maxpost'] - npost, $DEVIANT['maxpostartist'] - pcount].min)
    post_list += plist
    npost += plist.size
    pcount += plist.size

=begin
    # DeviantArtではページにわかれていない
    page = 1
    while npost < $PARAM['pixiv']['maxpost'] && pcount < $PARAM['pixiv']['maxpostartist'] && nextbutton != nil
      page += 1
      article_urls, nextbutton = getinfo_illustration("#{PIXIVARTISTURL}#{artist_id}#{PIXIVARTISTOPT}?p=#{page}", @session)
      plist = select_news(article_urls, [$PARAM['pixiv']['maxpost'] - npost, $PARAM['pixiv']['maxpostartist'] - pcount].min)
      post_list += plist
      npost += plist.size
      pcount += plist.size
    end
=end
  end
  post_list
end

def main
  option = init
  begin
    nimage = 0
    case option
    when 'select'
      @artists = Hash.new
      as = @db.read_artist(DEVIANTSITEID)
      $DEVIANT['select'].each do |k, v|
        @artists[k] = as[k] if as[k] != nil
      end
      posts = select_posts
      posts.each_with_index do |post_url, i|
        STDERR.print "(#{i+1}/#{posts.size}) POST #{post_url}: "
        nimg = load_page_sel(post_url)
        STDERR.puts "#{nimg} images are downloaded"
        nimage += nimg
      end
    when /\d+/ 
      @artists = @db.read_artist(DEVIANTSITEID)
      nimage = load_page_sel(option)
    else
      @artists = @db.read_artist(DEVIANTSITEID)
      #update_artists
      posts = select_posts
      posts.each_with_index do |post_id, i|
        STDERR.print "(#{i+1}/#{posts.size}) POST #{post_id}: "
        nimg = load_page_sel(post_id)
        STDERR.puts "#{nimg} images are downloaded"
        nimage += nimg
      end
    end
    STDERR.puts "TOTAL #IMAGE: #{nimage} images are downloaded."
  rescue => e
    STDERR.puts "ERROR: #{e}" if DEBUG
  ensure
    @session.quit
    @db.close if @db
  end
end

main


#---

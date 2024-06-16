!#/usr/bin/ruby

require 'socket'
require 'open-uri'
require 'rubygems'
require 'fileutils'
require 'selenium-webdriver'
require 'mysql'

require_relative 'eptanklib'
require_relative 'pixivlib'

USAGE = "pixivload.rb <YAML config> [<post id>]"
DEBUG = true
TIMEOUT = 300
#UA = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/51.0.2704.103 Safari/537.36"
UA = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/115.0.0.0 Safari/537.36'

PIXIVSITEID    = 1
PIXIVHOST      = 'https://www.pixiv.net/'
PIXIVLOGIN     = 'https://accounts.pixiv.net/'
PIXIVARTISTURL = PIXIVHOST + 'users/'
PIXIVPOSTURL   = PIXIVHOST + 'artworks/'
PIXIVIMGURL    = 'https://i.pximg.net/img-original/img'
#PIXIVARTISTOPT = '/illustrations/R-18'
PIXIVARTISTOPT = '/illustrations/'
PIXIVOPEID     = '11'
PIXIVMAXPOST   = 50
PIXIVMAXPAGE   = 100

PIXIVSELECT    = {
  '94953388'  => 'HAL-sexyグラドル部',
  #'92580782'  => 'AI Beauty',
  '94293536'  => 'AI Harem',
  '91987609'  => 'Ai_pyramid',


}

PIXIVSELECT2    = {
  '92580782'  => 'AI Beauty',
  '94624609'  => 'AI_Engine',
  '14732050'  => 'AI_Factory',
  '94293536'  => 'AI Harem',
  '92674085'  => 'AI hentai girl',
  '91987609'  => 'Ai_pyramid',
  '91993460'  => 'AI美女図鑑',
  '4090481'   => 'AkaTsuki',
  '86628914'  => 'aksen',
  '92471431'  => 'ApaDepa',
  '96329393'  => 'armpitmania2',  #  （綺麗なお姉さん、腋）
  '91659277'  => 'Beautiful Asian',
  '93710453'  => 'Chama',
  '92083772'  => 'CTR57',
  '88129804'  => 'DeepFlowAI',  # 超リアル
  '34361103'  => 'DryAI',  #  (超リアル)
  '92543253'  => 'ENA IZUMI',
  '1081940'   => 'EPW',
  '92621256'  => 'eroai', #（超綺麗なヌード）
  '92200178'  => 'Harui',
  '94953388'  => 'HAL-sexyグラドル部',
  '94472057'  => 'HouseOfGirls',
  '93236095'  => 'JKBOX',
  '92374415'  => 'LAIKA',
  '91897081'  => 'MACHOKING', #（お姉さんヌード、股多い）
  '92842827'  => 'MACHUWA',
  '1244958'   => 'Maitake',   #  (超リアル)
  '95912810'  => 'MIA',
  '85958675'  => 'MJ-Warrior',
  '49365915'  => 'nanairo52', #（超リアルのお姉さんヌード）
  '15006443'  => 'OG',
  '93272957'  => 'PinkKirby',
  '92827046'  => 'PIXAIAN',
  '93842479'  => 're-fan', #（リアルお姉さん）
  '91956444'  => 'realis_g',
  '140507'    => 'rei25',
  '34103660'  => 'RTA',
  '81519445'  => 'SANA666',
  '91430750'  => 'Sanity',
  '2094820'   => 'SDI',
  '824773'    => 'sistaelephants',  # ノースリーブ
  '91848683'  => 'StTsubasa',
  '94077908'  => 'SUNNY',
  '57876684'  => 'WetLady',  #  （乳集団）
  '91847721'  => '【AIイラスト】akane',
  '90760370'  => 'あい',
  '91598121'  => 'さんなり', # （リアルお姉さん、今後に期待）
  '1579615'   => 'したの',
  '42628079'  => 'だっちゅーの@AI-art',
  '94104308'  => '野魄',
  '64837766'  => '破廉恥太郎(ハレンチタロウ)',


}

# Patreon
# AIART                  10 -> 0    生々しくエロいがアソコがリアルじゃない
# AI ENA IZUMI           5 -> 0     アソコがリアルじゃない
# AI Factory             5 -> 0     えぐいが細部はあまり。。でもやっぱりいいのある
# AI Porn Gravure Girls  10 -> 0    全部モザイクあり
# AI_R18                 5
# Asian Girl             6          超リアルお姉さん
# Bukker                 ? -> ?     顔の比率が多い
# Eroai                  7 -> 0     非常に綺麗だが当たり少ない（綺麗系はImagined...で）
# GikoKitune             5          食傷気味
# HAL-sexyグラドル部     30 -> 0    モザイクあり、残念
# Imagined Cosplay       5
# Lote.                  8 -> 0     ありきたり
# ozin007                6
# PinkKirby              5
# realis_g               5 -> 0     link available!!
# studio Zue             5 -> 0     モザイクあり、残念
# unclear                7 -> 0     アソコがリアルじゃない

MAXARTISTLINE = 25
MAXIMG = 1000
#MAXPOST = 1
#MAXPOSTARTIST = 1
MAXWAIT = 5          # wait seconds for page navigation

def init
  if ARGV.size != 1 && ARGV.size != 2
    STDERR.puts USAGE
    exit 1
  end

  $PARAM = load_config(ARGV[0])

  @db = EpTank.new($PARAM['database'])
  @session = WebSession.new(WebSession::WITHSCR, $PARAM['chromeprofile'])
  
  # 初期ページ
  @session.navigate PIXIVLOGIN

  # 「同意」ボタンを押す（特別な時だけ？）
  begin
    @session.click('//*[@id="js-privacy-policy-banner"]/div/div/button', 2)
    # 「サインイン」ボタンを押す
    @session.click('/html/body/div[2]/div/div/div[3]/div[1]/a[2]', 2)

    # ログイン
    @session.send_keys($PARAM['pixiv']['id'], '//*[@id="app-mount-point"]/div/div/div[3]/div[1]/div[2]/div/div/div/form/fieldset[1]/label/input', 0)
    @session.send_keys($PARAM['pixiv']['pw'], '//*[@id="app-mount-point"]/div/div/div[3]/div[1]/div[2]/div/div/div/form/fieldset[2]/label/input', 0)
    @session.click('//*[@id="app-mount-point"]/div/div/div[3]/div[1]/div[2]/div/div/div/form/button', 3)
  rescue => e
    STDERR.puts "LOGIN process is passed." if DEBUG
  end

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
    body = URI.open(url, "User-Agent" => UA, :read_timeout => TIMEOUT, "Referer" => PIXIVHOST) do |f|
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
  STDERR.puts "URL: #{url}" if DEBUG
  charset = nil
  succ = false
  begin
    body = URI.open(url, "User-Agent" => UA, :read_timeout => TIMEOUT, "Referer" => PIXIVHOST) do |f|
      charset = f.charset
      f.read
    end
    dldir = "#{$PARAM['eptank']['dir']}#{@artists[artist_id]}"
    if File.exist?(dldir) == false
      FileUtils.mkdir(dldir)
    end
    imgfile = url.split("/")[-1]
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

def load_page_sel(post_id)
  purl = PIXIVPOSTURL + post_id
  return 0 if @db.exist_post?(purl)

  artist_id, artist_nm, title, image_urls = getinfo_artwork(purl, @session)
  return 0 if artist_id == nil

  if @artists[artist_id] == nil
    @db.update_artists({artist_id => artist_nm})
    @artists[artist_id] = artist_nm
  end

  prefix = Time.now.strftime("%Y%m%d%H%M%S%L") + "-#{artist_id}"
  nimg = 0
  image_urls.each do |u|
    next unless load_image2(u, prefix, artist_id, post_id)
    nimg += 1
  end

  if nimg > 0
    @db.regist_post(PIXIVSITEID, title, artist_id, purl, '', '', nimg)
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
      post_id = u.split("/")[-1]
      plist << post_id
      np -= 1
    end
  end
  plist
end

def select_posts
  post_list = Array.new
  npost = 0

  @artists.keys.shuffle.each do |artist_id|
    next if artist_id == PIXIVOPEID # IDがPIXIV事務局ならスキップ
    break if npost >= $PARAM['pixiv']['maxpost']
    pcount = 0

    STDERR.puts "ARTISTID: #{artist_id}" if DEBUG
    article_urls, nextbutton = getinfo_illustration("#{PIXIVARTISTURL}#{artist_id}#{PIXIVARTISTOPT}?p=1", @session)
    plist = select_news(article_urls, [$PARAM['pixiv']['maxpost'] - npost, $PARAM['pixiv']['maxpostartist'] - pcount].min)
    post_list += plist
    npost += plist.size
    pcount += plist.size

    page = 1
    while npost < $PARAM['pixiv']['maxpost'] && pcount < $PARAM['pixiv']['maxpostartist'] && nextbutton != nil
      page += 1
      article_urls, nextbutton = getinfo_illustration("#{PIXIVARTISTURL}#{artist_id}#{PIXIVARTISTOPT}?p=#{page}", @session)
      plist = select_news(article_urls, [$PARAM['pixiv']['maxpost'] - npost, $PARAM['pixiv']['maxpostartist'] - pcount].min)
      post_list += plist
      npost += plist.size
      pcount += plist.size
    end
  end

  post_list
end

def main
  option = init
  begin
    nimage = 0
    case option
    when /\d+/ 
      @artists = @db.read_artist(PIXIVSITEID)
      nimg = load_page_sel(option)
    when 'select'
      #@artists = PIXIVSELECT
      @artists = $PARAM['pixiv']['select']
      posts = select_posts
      posts.each_with_index do |post_id, i|
        STDERR.print "(#{i+1}/#{posts.size}) POST #{post_id}: "
        nimg = load_page_sel(post_id)
        STDERR.puts "#{nimg} images are downloaded"
        nimage += nimg
      end
    else
      @artists = @db.read_artist(PIXIVSITEID)
      puts "STEP 1"
      update_artists
      puts "STEP 2"
      posts = select_posts
      puts "STEP 3"
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

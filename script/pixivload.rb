!#/usr/bin/ruby

require 'socket'
require 'open-uri'
require 'rubygems'
require 'fileutils'
require 'selenium-webdriver'
require 'mysql'

require_relative 'eptanklib'

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
PIXIVSELECT    = [
  91191937,  # MAIK09 (UP画像多数、無修正)
  88129804,  # DeepFlowAI (超リアル)
  57876684,  # WetLady （乳集団）
  34361103,  # DryAI (超リアル)
  1244958,   # Maitake (超リアル)
  96329393,  # armpitmania2 （綺麗なお姉さん、腋）
  97079130,  # coco （リアル系イラスト、乳綺麗）
  13979832,  # AI OFUG （リアルお姉さん）
  92621256,  # eroai （超綺麗なヌード）
  74032681,  # Zeroling91 （エロ乳お姉さん）
  91897081,  # MACHOKING （お姉さんヌード、股多い）
  2068607,   # satankun  （調乳娘）
  6046076,   # StudioZue （お股多い可愛い系イラスト）
  49365915,  # nanairo52 （超リアルのお姉さんヌード）
  140507,    # rei25 (超リアル、年増あり)
  92629620,  # momiji0920@AI （リアルお姉さん）
  94484133,  # AI Artmage （リアルお姉さん）
  93842479,  # re-fan （リアルお姉さん）
  87784294,  # CudaSmoke （美女！）
  2094820,   # SDI （リアルお姉さん）
  91598121,  # さんなり （リアルお姉さん、今後に期待）
  90748889,  # AIbot （綺麗系巨乳）
  #4090481,   # AkaTsuki
  #92200178,  # Harui
  #18866024,  # 鸽鸽下面羊死了
  #36972434,  # Kote_party

  #94624609,  # AI_Engine
  #94077908,  # SUNNY
  #92650235,  # ai_sakura
  #95912810,  # MIA
  #92580782,  # AI Beauty
]

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
# realis_g               5 -> 0     画像がほとんどなかった、取得できなかった
# studio Zue             5 -> 0     モザイクあり、残念
# unclear                7 -> 0     アソコがリアルじゃない

MAXARTISTLINE = 25
MAXIMG = 1000
MAXPOST = 2
MAXPOSTARTIST = 2
MAXWAIT = 5          # wait seconds for page navigation

def init
  if ARGV.size != 1 && ARGV.size != 2
    STDERR.puts USAGE
    exit 1
  end

  $PARAM = load_config(ARGV[0])

  @session = WebSession.new(WebSession::WITHSCR)
  
  # 初期ページ
  #@session.navigate.to PIXIVLOGIN
  @session.navigate PIXIVLOGIN

  #sleep MAXWAIT
  # 「同意」ボタンを押す（特別な時だけ？）
  #link = @session.find_element(:xpath, '//*[@id="js-privacy-policy-banner"]/div/div/button')
  #link.click
  @session.click('//*[@id="js-privacy-policy-banner"]/div/div/button')

  #sleep MAXWAIT
  #link = @session.find_element(:xpath, '/html/body/div[2]/div/div/div[3]/div[1]/a[2]')
  #link.click
  @session.click('/html/body/div[2]/div/div/div[3]/div[1]/a[2]')

  # ログイン
  #sleep MAXWAIT
  #ele_user = @session.find_element(:xpath, '//*[@id="app-mount-point"]/div/div/div[3]/div[1]/div[2]/div/div/div/form/fieldset[1]/label/input')
  #ele_user.send_keys($PARAM['pixiv']['id'])
  @session.send_keys($PARAM['pixiv']['id'], '//*[@id="app-mount-point"]/div/div/div[3]/div[1]/div[2]/div/div/div/form/fieldset[1]/label/input')

  #ele_pass = @session.find_element(:xpath, '//*[@id="app-mount-point"]/div/div/div[3]/div[1]/div[2]/div/div/div/form/fieldset[2]/label/input')
  #ele_pass.send_keys($PARAM['pixiv']['pw'])
  @session.send_keys($PARAM['pixiv']['pw'], '//*[@id="app-mount-point"]/div/div/div[3]/div[1]/div[2]/div/div/div/form/fieldset[2]/label/input', 0)

  #link = @session.find_element(:xpath, '//*[@id="app-mount-point"]/div/div/div[3]/div[1]/div[2]/div/div/div/form/button')
  #link.click
  @session.click('//*[@id="app-mount-point"]/div/div/div[3]/div[1]/div[2]/div/div/div/form/button', 0)

  # サイドメニューを消す
  #sleep 60
  #link = @session.find_element(:xpath, '/html/body/div[7]/div/div[2]/div/div[1]/div[1]/div/button')
  #link.click
  #sleep 5

  #uid = session.find_element(:xpath, '/html/body/span[1]')
  #STDERR.puts "USER ID: #{uid.tag_name}, #{uid.text}" if DEBUG

  post_id = ARGV[1]
  return post_id
end

=begin
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
=end

def exist_post?(url)
  cnt = 0
  begin
    sql = <<-SQL
      SELECT COUNT(id) FROM article WHERE url = ?;
    SQL
    st = @db.prepare(sql)
    st.execute(url).each do |c|
      cnt = c[0]
    end
  rescue => e
    STDERR.puts "DB ERROR: #{e}" if DEBUG
  end
  cnt == 1
end

def regist_post(title, artist_id, purl, post_time, ext, nimage)
  begin
    sql = <<-SQL
      SELECT artist.id FROM artist, enroll
      WHERE enroll.userid = ? AND artist.id = enroll.artist_id;
    SQL
    aid = nil
    st = @db.prepare(sql)
    st.execute(artist_id).each do |a|
      aid = a[0]
    end
    sql = <<-SQL
      INSERT INTO article (title, url, ext, nimage, optinfo, active, site_id, artist_id)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?);
    SQL
    st = @db.prepare(sql)
    st.execute(title, purl, ext, nimage, post_time, true, PIXIVSITEID, aid)
    @db.commit
  rescue => e
    STDERR.puts "REGIST POST ERROR: #{e}"
    @db.rollback
  end
end

def read_artist
  @artists = Hash.new
  begin
    sql = <<-SQL
      SELECT userid, username FROM enroll
      WHERE site_id = ? AND active = true;
    SQL
    st = @db.prepare(sql)
    st.execute(PIXIVSITEID).each do |uid, unm|
        @artists[uid] = unm
    end
  rescue => e
    STDERR.puts "READ ARTIST ERROR: #{e}"
  end
  STDERR.puts "READ ARTIST: #{@artists.size} artists!" if DEBUG
end

def exist_artist?(artist_id)
  cnt = 0
  act = false
  begin
    sql = <<-SQL
      SELECT artist_id, active FROM enroll WHERE userid = '#{artist_id}';
    SQL
    @db.query(sql).each do |id, a|
      cnt += 1
      act = a
      #STDERR.puts "ROW: #{id}, #{a}, AID=#{artist_id}" if DEBUG
    end
  rescue => e
    STDERR.puts "DB ERROR (ARTIST): #{e}" if DEBUG
  end
  return cnt == 1, act
end

def update_db_artists(diff_artists)
  diff_artists.each do |k, v|
    STDERR.puts "ARTIST: #{k}/#{v}" if DEBUG
    begin
      ex, act = exist_artist?(k)
      if ex == true #
        if v == nil
          if act == true
            sql = <<-SQL
              UPDATE enroll SET active = false WHERE userid = '?';
            SQL
            st = @db.prepare(sql)
            st.execute(k)
            @db.commit
          end
        else
          if act == false
            sql = <<-SQL
              UPDATE enroll SET active = true WHERE userid = '?';
            SQL
            st = @db.prepare(sql)
            st.execute(k)
            @db.commit
          end
        end
      else
        if v != nil
          sql = <<-SQL
            INSERT INTO artist (name, rating, active)
            VALUES (?, 0, true);
          SQL
          st = @db.prepare(sql)
          st.execute(v)

          sql = <<-SQL
            SELECT id FROM artist WHERE name = '#{v}';
          SQL
          id = 0
          @db.query(sql).each do |i|
            id = i[0]
          end
          #STDERR.puts "ID=#{id[0]}"

          if id > 0
            sql = <<-SQL
              INSERT INTO enroll (site_id, artist_id, userid, username, url, fee, active)
              VALUES (#{PIXIVSITEID}, ?, ?, ?, ?, 0, true);
            SQL
            url = "#{PIXIVARTISTURL}#{k}"
            st = @db.prepare(sql)
            st.execute(id, k, v, url)
            @db.commit
          end
        end
      end
    rescue => e
      STDERR.puts "REGIST ARTIST ERROR: #{e}" if DEBUG
      @db.rollback
    end
  end
end

def regist_image(filename, post_id, artist_id)
  begin
    sql = <<-SQL
      SELECT article.id FROM article WHERE article.url = ?;
    SQL
    pid = nil
    st = @db.prepare(sql)
    st.execute(post_id).each do |p|
      pid = p[0]
    end

    sql = <<-SQL
      SELECT artist.id FROM artist, enroll
      WHERE enroll.userid = ? AND artist.id = enroll.artist_id;
    SQL
    aid = nil
    st = @db.prepare(sql)
    st.execute(artist_id).each do |a|
      aid = a[0]
    end

    sql = <<-SQL
      INSERT INTO image (filename, rating, active, article_id, artist_id)
      VALUES (?, 0, true, ?, ?);
    SQL
    st = @db.prepare(sql)
    st.execute(filename, pid, aid)
    @db.commit
  rescue => e
    STDERR.puts "REGIST IMAGE ERROR: #{e}"
    @db.rollback
  end

end

def open_db
  begin
    @db = Mysql.new(hostname: $PARAM['database']['host'], username: $PARAM['database']['user'],
                    password: $PARAM['database']['pass'], port:     $PARAM['database']['port'],
                    database: $PARAM['database']['name'], charset:  $PARAM['database']['charset'])
    @db.connect
  rescue => e
    STDERR.puts "DB OPEN ERROR: #{e}"    
  end
end

def close_db
  @db.close
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
    regist_image(fname, post_id, artist_id)
    succ = true
  rescue => e
    STDERR.puts "LOAD ERROR: #{e}" if DEBUG
    succ = false
  end
  succ
end  

def load_page_sel(post_id)
  purl = PIXIVPOSTURL + post_id
  return 0 if exist_post?(purl)

  # 対象ページへ遷移
  #@session.navigate.to purl
  @session.navigate purl

  #sleep 5
  #artisturl = @session.find_element(:xpath, '//*[@id="root"]/div[2]/div/div[3]/div/div/div[1]/aside/section[1]/h2/div/div/a')
  #artist_id = artisturl.attribute('href').split("/")[-1]
  artist_id = @session.attribute('href', '//*[@id="root"]/div[2]/div/div[3]/div/div/div[1]/aside/section[1]/h2/div/div/a')[-1]
  if @artists[artist_id] == nil
    #eleartist = @session.find_element(:xpath, '//*[@id="root"]/div[2]/div/div[3]/div/div/div[1]/aside/section[1]/h2/div/div/a/div')
    #artist_nm = eleartist.text
    artist_nm = @session.text('//*[@id="root"]/div[2]/div/div[3]/div/div/div[1]/aside/section[1]/h2/div/div/a/div', 0)
    update_db_artists({artist_id => artist_nm})
    @artists[artist_id] = artist_nm
  end
  sleep 1
  title = 'NO TITLE'
  begin
    #eletitle  = @session.find_element(:xpath, '//*[@id="root"]/div[2]/div/div[3]/div/div/div[1]/main/section/div[1]/div/figcaption/div/div/h1')
    #title     = eletitle.text
    title = @session.text('//*[@id="root"]/div[2]/div/div[3]/div/div/div[1]/main/section/div[1]/div/figcaption/div/div/h1')
  rescue => e
    STDERR.puts "NO TITLE: #{post_id}" if DEBUG
  end

  #element = nil
  html = nil
  begin
    image_xpath = nil
    begin
      # "すべて見る"ボタンをクリック
      #link = @session.find_element(:xpath, '//*[@id="root"]/div[2]/div/div[3]/div/div/div[1]/main/section/div[1]/div/div[4]/div/div[2]/button/div[2]')
      #link.click
      @session.click('//*[@id="root"]/div[2]/div/div[3]/div/div/div[1]/main/section/div[1]/div/div[4]/div/div[2]/button/div[2]')

      #sleep 5
      #element = @session.find_element(:xpath, '//*[@id="root"]/div[2]/div/div[3]/div/div/div[1]/main/section/div[1]/div/figure/div[1]/div[2]/div[2]/a')
      image_xpath = '//*[@id="root"]/div[2]/div/div[3]/div/div/div[1]/main/section/div[1]/div/figure/div[1]/div[2]/div[2]/a'
    rescue
      #element = @session.find_element(:xpath, '//*[@id="root"]/div[2]/div/div[3]/div/div/div[1]/main/section/div[1]/div/figure/div[1]/div[1]/div/a')
      image_xpath = '//*[@id="root"]/div[2]/div/div[3]/div/div/div[1]/main/section/div[1]/div/figure/div[1]/div[1]/div/a'
    end
    html = @session.attribute('href', image_xpath)
  rescue => e
    STDERR.puts "PAGE NOT IMAGE?: #{e}" if DEBUG
    return 0
  end

  #html = element.attribute('href')
  STDERR.puts "HREF: #{html}" if DEBUG
  html =~ /img-original\/img(\/\d\d\d\d\/\d\d\/\d\d\/\d\d\/\d\d\/\d\d\/)#{post_id}_p\d+\.(\S+)$/
  date = $1
  ext  = $2

  pages = Array.new
  prefix = Time.now.strftime("%Y%m%d%H%M%S%L") + "-#{artist_id}"

  nimg = 0
  while nimg < MAXIMG do
    imgfile = "#{post_id}_p#{nimg}.#{ext}"
    break unless load_image(artist_id, prefix, date, imgfile, post_id)
    nimg += 1
  end
  if nimg > 0
    regist_post(title, artist_id, purl, date, ext, nimg)
  end
  nimg
end


def update_artists
  p = 1
  #@session.navigate.to "#{PIXIVARTISTURL}#{$PARAM['pixiv']['user']}/following?p=1"
  @session.navigate "#{PIXIVARTISTURL}#{$PARAM['pixiv']['user']}/following?p=1"
  
  #sleep 5
  #element = @session.find_element(:xpath, '//*[@id="root"]/div[2]/div/div[3]/div/div/div[2]/div[2]/div[2]/div/section/div[1]/div/div/div/span')
  #nfollow = element.text.to_i
  nfollow = @session.text('//*[@id="root"]/div[2]/div/div[3]/div/div/div[2]/div[2]/div[2]/div/section/div[1]/div/div/div/span').to_i

  STDERR.puts "NFOLLOW/@ARTIST: #{nfollow}/#{@artists.size}" if DEBUG
  return if (nfollow - @artists.size).abs < 10  #差が10未満なら許容する
  #return if nfollow == @artists.size

  curr_artists = Hash.new
  loop do # loop per following page
    begin
      MAXARTISTLINE.times do |al|
        begin
          #artist = @session.find_element(:xpath, "//*[@id=\"root\"]/div[2]/div/div[3]/div/div/div[2]/div[2]/div[2]/div/section/div[2]/div[#{al+1}]/div/div[1]/div/a")
          #artist_id = artist.attribute('href').split("/")[-1]
          artist_id = @session.attribute('href', "//*[@id=\"root\"]/div[2]/div/div[3]/div/div/div[2]/div[2]/div[2]/div/section/div[2]/div[#{al+1}]/div/div[1]/div/a")[-1]

          #artist_name = @session.find_element(:xpath, "//*[@id=\"root\"]/div[2]/div/div[3]/div/div/div[2]/div[2]/div[2]/div/section/div[2]/div[#{al+1}]/div/div[1]/div/div/div[1]/a").text
          artist_name = @session.text("//*[@id=\"root\"]/div[2]/div/div[3]/div/div/div[2]/div[2]/div[2]/div/section/div[2]/div[#{al+1}]/div/div[1]/div/div/div[1]/a")

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

    #nextbutton = @session.find_elements(:xpath, "//*[@id=\"root\"]/div[2]/div/div[3]/div/div/div[2]/nav/a")[-1]
    nextbutton = @session.element_nth("//*[@id=\"root\"]/div[2]/div/div[3]/div/div/div[2]/nav/a", -1)

    break if nextbutton.attribute('hidden') == 'true'
    nextbutton.click
    #sleep MAXWAIT
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

  update_db_artists(diff_artists)
end

def select_posts
  post_list = Array.new
  npost = 0
  @artists.keys.shuffle.each do |artist_id|
    next if artist_id == PIXIVOPEID # IDがPIXIV事務局ならスキップ
    break if npost >= MAXPOST

    STDERR.puts "ARTISTID: #{artist_id}" if DEBUG
    #@session.navigate.to "#{PIXIVARTISTURL}#{artist_id}"
    #@session.navigate.to "#{PIXIVARTISTURL}#{artist_id}#{PIXIVARTISTOPT}"  # R-18のみ抽出
    #sleep 5
    @session.navigate "#{PIXIVARTISTURL}#{artist_id}#{PIXIVARTISTOPT}"
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
          #element = @session.find_element(:xpath, "//*[@id=\"root\"]/div[2]/div/div[3]/div/div/div[2]/div[3]/div/div/section/div[3]/div/ul/li[#{i+1}]/div/div[1]/div/a")
          #post_id = element.attribute('href').split("/")[-1]
          #purl = PIXIVPOSTURL + post_id
          purl = @session.attribute('href', "//*[@id=\"root\"]/div[2]/div/div[3]/div/div/div[2]/div[3]/div/div/section/div[3]/div/ul/li[#{i+1}]/div/div[1]/div/a")
          post_id = purl.split("/")[-1]
          unless exist_post?(purl)
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

        #nextbutton = @session.find_elements(:xpath, "//*[@id=\"root\"]/div[2]/div/div[3]/div/div/div[2]/nav/a")[-1]
        nextbutton = @session.element_nth("//*[@id=\"root\"]/div[2]/div/div[3]/div/div/div[2]/nav/a", -1)

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

def main
  post_id = init
  begin
    open_db
    read_artist

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
end

main


#---

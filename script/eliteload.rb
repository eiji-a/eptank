#!/usr/bin/ruby
#
# elite babes loader
#

require 'socket'
require 'open-uri'
require 'fileutils'
require 'rubygems'
require 'zip'
#require 'selenium-webdriver'

require_relative 'eptanklib2'
require_relative 'elitelib'

USAGE = "eliteload.rb <YAML config> [help|<selection>]"
DEBUG = true
TIMEOUT = 300
MAXCOLPAGES = 2  # 一覧ページを何ページまで走査するかを指定
#MAXMODELPAGES = 1
MAXARTICLES = 500
MAXMODELARTICLES = 5
RETRY = 20
INFOFILE = '_info.txt'

def init
  if ARGV.size < 1 || ARGV.size > 2
    STDERR.puts USAGE
    exit 1
  end

  $PARAM = load_config(ARGV[0])

  if ARGV[1] == 'help'
    STDERR.puts USAGE
    STDERR.puts "SELECT: #{$PARAM['elite']['select'].keys.join('  ')}"
    exit 1
  end

  @db = EpTank.new($PARAM['database'])
  @session = WebSession.new(WebSession::WITHSCR, $PARAM['chromprofile'])
  @tankdir = "#{$PARAM['eptank']['dir']}#{$PARAM['elite']['site']}/"
  @tmpdir = $PARAM['eptank']['tmpdir']

  begin
    #STDERR.puts "SITE: #{$PARAM['elite']['select']}"
    @site_id, @site_url = @db.get_site_info($PARAM['elite']['site'])
    #STDERR.puts "ID|URL: #{@site_id}|#{@site_url}"
    selection = if ARGV.size == 2 && $PARAM['elite']['select'][ARGV[1]] != nil then ARGV[1] else 'models' end
    @select = $PARAM['elite']['select'][selection]
  rescue => e
    STDERR.puts "ERROR init: #{e}"
  end

  #STDERR.puts "SEL: #{ARGV[1]} , #{@select}"
  return ARGV[1]

end

def get_imagedata(url)
  charset = nil
  #url2 = (URI.encode_www_form_component url).gsub("../", "")
  url2 = url
  body = ""
  succ = false
  RETRY.times do |i|
    begin
      body = URI.open(url2, "User-Agent" => WebSession::UA, :read_timeout => TIMEOUT) do |f|
        charset = f.charset
        f.read
      end
      succ = true
      break
    rescue StandardError => e
      STDERR.puts "LOAD ERROR & RETRY(#{i}:#{url2}): #{e}"
      if e.to_s == '404 Not Found'
        url = url.gsub(".jpg", ".png")
      end
    end
  end
  if succ == true
    return charset, body
  else
    return nil, nil
  end
end

def download_image(tmpfile, imgurl)
  File.open(tmpfile, 'w') do |fp|
    charset, body = get_imagedata(imgurl)
    if body != nil
      fp.write(body)
    end
  end
  get_image_info(tmpfile)
end

def create_cbz(mname, title, images)
  return '', [] if images.size == 0

  #images[0] =~ /¥/(¥d+)¥/(.*)$/
  bnum = images[0].split('/')[-2]
  dname = "#{bnum}-" + Time.now.strftime("%Y%m%d%H%M%S")
  FileUtils.mkdir("#{@tmpdir}#{dname}")

  imginfo = Array.new
  begin
    strdir = "#{@tankdir}#{mname}/"
    zipfile = dname + '.zip'
    Zip::File.open(@tmpdir + zipfile, Zip::File::CREATE) do |zfp|
      tmpdname = "#{@tmpdir}#{dname}"
      File.open("#{tmpdname}/#{INFOFILE}", 'w') do |fp|
        fp.puts "model: #{mname}"
        fp.puts "title: #{title}"
      end
      zfp.add(INFOFILE, "#{tmpdname}/#{INFOFILE}")

      imglist = images.map do |im|
        fname = "#{bnum}-" + File.basename(im)
        tmpfile = "#{tmpdname}/#{fname}"
        [fname, tmpfile, im]
      end
      
      threads = Array.new
      imglist.each do |img|
        threads << Thread.new(img) { |img|
          download_image(img[1], img[2])
        }
      end

      imginfo = Array.new
      threads.each do |th|
        imginfo << th.value
      end
      imglist.each do |i|
        zfp.add(i[0], i[1])
      end

    end
    FileUtils.mv("#{@tmpdir}#{zipfile}", "#{@tmpdir}#{dname}.cbz")
    FileUtils.rm_rf("#{@tmpdir}#{dname}")
  rescue => e
    STDERR.puts "LOAD IMAGES ERROR: #{e}"
  end

  return "#{dname}.cbz", imginfo
end

def scrape_article(url)
  #STDERR.puts "URL: #{url}/#{url.class}"
  images = []
  chk = check_tags(@session)
  return '', images if chk == false
  title, images = get_images(url, @session)

  return title, images
end

def regist_article(url, artist_id, mname, title, cbzfile, imginfo)
  #STDERR.puts "TITLE: #{title}"
  cbzpath = "#{$PARAM['elite']['site']}/#{mname}/"
  tankdir = "#{$PARAM['eptank']['dir']}"
  #regdir = "#{$PARAM['elite']['site']}/#{mname}/"
  begin
    Dir.mkdir("#{tankdir}#{cbzpath}") if Dir.exist?("#{tankdir}#{cbzpath}") == false
    FileUtils.move("#{@tmpdir}#{cbzfile}", "#{tankdir}#{cbzpath}#{cbzfile}")
  rescue StandardError => e
    STDERR.puts "REGIST ERROR(#{url}) can't create CBZ file: #{e}"
    return
  end
  begin
    article_id = @db.regist_article2(@site_id, title, url, imginfo.size, '', artist_id)
    #STDERR.puts "ARTICLE_ID= #{article_id}"
    raise StandardError.new("Can't regist article (#{url})") if article_id == nil
    fsize = File.size("#{tankdir}#{cbzpath}#{cbzfile}")
    image_id = @db.regist_image2("#{cbzpath}#{cbzfile}", fsize, 'cbz', nil, nil, nil, 1, article_id, artist_id, nil)
    raise StandardError.new("Can't regist cbz image (#{url})") if image_id == nil
    imginfo.each do |im|
      im_id = @db.regist_image2(im[0], im[1], im[2], im[3], im[4], im[5], 1, article_id, artist_id, image_id)
      raise StandardError.new("Can't regist sub image (#{im[0]})") if im_id == nil
    end
    @db.commit
  rescue StandardError => e
    STDERR.puts "REGIST ERROR(#{url}) can't regist to DB: #{e}"
  end
end

def download_article(url, artist_id, mname, mcode)
  modelname = "#{mname}(#{mcode})"
  title = ''
  images = []
  begin
    title, images = scrape_article(url)
  rescue => e
    STDERR.puts "dl ERROR: #{e}/#{url}"
    return false
  end
  return false if images.size == 0

  if images[0] =~ /javascript/ || images.size < 5 
    STDERR.puts "IMGVDO: #{images}"
    @narticle -= 1
    stat = false
  else
    cbzfile, imginfo = create_cbz(modelname, title, images)
    regist_article(url, artist_id, modelname, title, cbzfile, imginfo)
    STDERR.puts "#{mname}:#{artist_id} (#{imginfo.size} images): #{title}"
  end
  true
end

def scrape_modelpage(url, pg)
  mcode = url.split("/")[-1]
  url2 = "#{url}/mpage/#{pg}/"
  articles = Array.new
  @session.navigate(url2, 2)
  mname = ''
  begin
    chk = check_tags(@session)
    return '', [] if chk == false

    mname = get_modelname(@session)
    #STDERR.puts "SCMOD: #{url} / #{pg}"
    ars0 = get_articles(@session)
  rescue => e
    STDERR.puts "SCRAPE MODELPAGE ERROR: #{e}/#{url}"
  end

  #STDERR.puts "NARS0: #{ars0.size}"
  ars0.each do |ar|
    break if @narticle >= MAXARTICLES
    break if @nmodelpage >= MAXMODELARTICLES

    #STDERR.puts "AR: #{ar}"
    if @db.exist_article?(ar) || ar =~ /video/
      #STDERR.puts "The Article is already exist: #{ar}"
    else
      articles << ar
      @narticle += 1
      @nmodelpage += 1
    end
  end

  articles2 = []
  if @narticle < MAXARTICLES
    begin
      ele = @session.element('//*[@id="content"]/nav/ul/li[3]', 0)
      mn, mc, articles2 = scrape_modelpage(url, pg + 1) if ele != nil
    rescue StandardError => e
      #STDERR.puts "scrape error: #{e}"
    end
  end
  return mname, mcode, articles + articles2
end

def scrape_models(url, page)
  models = []
  return models if page > MAXCOLPAGES || page < 1

  #url2 = "#{url}page/#{page}/"
  url2 = url.gsub('<PAGE>', page.to_s)
  models = get_models(url2, @session)
  nextmodels = scrape_models(url, page + 1)

  models + nextmodels
end

def scrape_collection(url, page)
  models = Hash.new
  return models if page > MAXCOLPAGES || page < 1

  url2 = url.gsub('<PAGE>', page.to_s)
  cols = get_collection(url2, @session)
  #STDERR.puts "PAGE=#{page}, SIZE=#{cols.size}"
  return models if cols.size == 0

  cols.each do |col|
    next if col =~ /video/
    aid, aurl = @db.get_artist_from_article(col)
    model = if aid == nil then
      STDERR.puts "NO EXIST: #{col}"
      get_modelinfo(col, @session)
    else
      #STDERR.puts "USE ENROLL!: #{aurl}"
      aurl
    end
    models[model] = true if model != ''
    #STDERR.puts "MODEL: #{model}/#{col}"
  end

  nextmodels = scrape_collection(url, page + 1)

  models.merge(nextmodels)
end

def main
  option = init
  @narticle = 0
  begin
    #STDERR.puts("scrape_collection: #{@select}")
    models = case @select 
      when /^models/
        scrape_models(@site_url + @select, 1)
      when /^tag/ || /^collection/

        scrape_collection(@site_url + @select, 1).keys
      else
        scrape_collection(@site_url + @select, 1).keys
      end

    puts "NMODELS: #{models.size}"

    models.shuffle.each do |mo|
      break if @narticle >= MAXARTICLES
      @nmodelpage = 0
      mname, mcode, articles = scrape_modelpage(mo, 1)
      #STDERR.puts "MODELURL: #{mname} / #{mcode} / #{articles}"
      artist_id = @db.add_artist(mname, mcode, true)
      st = @db.enroll_artist(mname, mcode, true, @site_id, artist_id, mo)
      if artist_id != nil && st == true
        @db.commit
      else
        next
      end

      modelname = "#{mname}(#{mcode})"
      STDERR.puts "ARTIST: #{artist_id} / #{modelname}"
      articles.each do |ar|
        STDERR.print "ARTICLE(#{@narticle}/#{MAXARTICLES}): "
        st = download_article(ar, artist_id, mname, mcode)
=begin
        title, images = scrape_article(ar)
        if images[0] =~ /javascript/ || images.size < 5 
          STDERR.puts "IMGVDO: #{images}"
        else
          cbzfile, imginfo = create_cbz(modelname, title, images)
          regist_article(ar, artist_id, modelname, title, cbzfile, imginfo)
          STDERR.puts "#{mname} (#{imginfo.size} images): #{title}"
        end
=end
      end
    end

    STDERR.puts "Loading is finished."
  rescue => e
    STDERR.puts "MAIN ERROR: #{e}"
  ensure
    @session.quit
    @db.close if @db
  end
end

main

#---

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
MAXCOLPAGES = 4  # 一覧ページを何ページまで走査するかを指定
#MAXMODELPAGES = 1
MAXARTICLES = 50
MAXMODELARTICLES = 5
RETRY = 20
INFOFILE = '_info.txt'
NOMODELINFO = 'NOMODELINFO'

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
  @session.navigate(url, 2)
  #STDERR.puts "URL: #{url}/#{url.class}"
  images = []
  chk = check_tags(@session)
  title, images = get_images(url, @session)

  return title, images, chk
end

def regist_article(url, artist_id, title, act, imgsize)
  article_id = @db.regist_article2(title, url, imgsize, '', act, @site_id, artist_id)
  STDERR.puts "REGIST ARTICLE: Can't regist article (#{url})" if article_id == nil
  article_id
end

def regist_images(modelname, cbzfile, imginfo, act, article_id, artist_id)
  cbzpath = "#{$PARAM['elite']['site']}/#{modelname}/"
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
    fsize = File.size("#{tankdir}#{cbzpath}#{cbzfile}")
    image_id = @db.regist_image2("#{cbzpath}#{cbzfile}", fsize, 'cbz', nil, nil, nil, 1, act, article_id, artist_id, nil)
    raise StandardError.new("Can't regist cbz image (#{url})") if image_id == nil
    imginfo.each do |im|
      im_id = @db.regist_image2(im[0], im[1], im[2], im[3], im[4], im[5], 1, act, article_id, artist_id, image_id)
      raise StandardError.new("Can't regist sub image (#{im[0]})") if im_id == nil
    end
    @db.commit
  rescue StandardError => e
    STDERR.puts "REGIST ERROR(#{url}) can't regist to DB: #{e}"
  end
end

def download_article(url, artist_id, mname, mcode, mact)
  modelname = "#{mname}(#{mcode})"
  title = ''
  images = []
  act = false
  begin
    title, images, act = scrape_article(url)
  rescue => e
    STDERR.puts "dl ERROR: #{e}/#{url}"
  end

  if images[0] =~ /javascript/ || images.size < 5 
    images = Array.new
    act = false
  end

  article_id = regist_article(url, artist_id, title, act, images.size)
  if mact == true && act == true && article_id != nil
    cbzfile, imginfo = create_cbz(modelname, title, images)
    regist_images(modelname, cbzfile, imginfo, act, article_id, artist_id)
    STDERR.puts "#{mname}:#{artist_id} (#{imginfo.size} images): #{title}"
  else
    STDERR.puts "#{mname}:#{artist_id}: The article is NOT ACTIVE or ALREADY DOWNLOADED."
    act = false
  end

  act
end

def scrape_modelinfo(url)
  @session.navigate(url, 2)
  mcode = url.split("/")[-1]
  mname = ''
  chk = false
  begin
    chk = check_tags(@session)
    #return '', [] if chk == false
    mname = get_modelname(@session)
  rescue => e
    STDERR.puts "SCRAPE MODELPAGE ERROR: #{e}/#{url}"
  end
  if mname != ''
    return mname, mcode, chk
  else
    return '', '', false
  end
end

def scrape_modelpage(url, pg)
  mcode = url.split("/")[-1]
  url2 = "#{url}/mpage/#{pg}/"
  #STDERR.puts "MODELPAGE: #{url2}"
  articles = Array.new
  @session.navigate(url2, 2)
  chk = false
  ars0 = Array.new
  begin
    chk = check_tags(@session)
    ars0 = get_articles(@session) if chk == true
  rescue => e
    STDERR.puts "SCRAPE MODELPAGE ERROR: #{e}/#{url}"
  end

  return [], false if chk == false

  #STDERR.puts "NARS0: #{ars0.size}"
  ars0.each do |ar|
    break if @nmodelpage >= MAXMODELARTICLES

    if @db.exist_article?(ar)
      #STDERR.puts "The Article is already exist: #{ar}"
    else
      STDERR.puts "AR: #{ar}"
      articles << ar
      @nmodelpage += 1
    end
  end

  articles2 = Array.new
  chk2 = true
  if articles.size < MAXARTICLES && @nmodelpage < MAXMODELARTICLES
    begin
      ele = @session.element('//*[@id="content"]/nav/ul/li[3]', 0)
      articles2, chk2 = scrape_modelpage(url, pg + 1) if ele != nil
    rescue StandardError => e
      #STDERR.puts "scrape error: #{e}"
    end
  end

  return articles + articles2, chk && chk2
end

def get_model(url)
  artist_id, mname, mcode, act = @db.get_artist_by_url(@site_id, url)
  if artist_id == nil
    mname, mcode, act = scrape_modelinfo(url)
    mname.gsub!(/'/, "''")
    #STDERR.puts "MODEL: #{mname}/#{mcode}/#{act}"
    if mname != ''
      artist_id = @db.add_artist(mname, mcode, act)
      st = @db.enroll_artist(mname, mcode, act, @site_id, artist_id, url)
      @db.commit if artist_id != nil && st == true
    end
  end
  return artist_id, mname, mcode, act
end

def scrape_models(url, page)
  return Array.new, Hash.new if page > MAXCOLPAGES || page < 1

  url2 = url.gsub('<PAGE>', page.to_s)
  modellist = get_models(url2, @session)
  STDERR.puts "MODELLIST: #{modellist.size}"

  models = modellist
  
  nextmodels, _articles = scrape_models(url, page + 1)

  #return models.merge(nextmodels), Hash.new
  return models + nextmodels, Hash.new
end

def scrape_collection(url, page)
  return Array.new, Hash.new if page > MAXCOLPAGES || page < 1
  url2 = url.gsub('<PAGE>', page.to_s)
  cols = get_collection(url2, @session)
  return Array.new, Hash.new if cols.size == 0

  modellist = Hash.new
  articles  = Hash.new
  cols.each do |col|
    break if @narticle >= MAXARTICLES

    eid, eurl, aurl = @db.get_artist_from_article(col)
    model = if eurl != nil then
      eurl
    elsif aurl != nil then
      NOMODELINFO
    else
      STDERR.puts "NO EXIST: #{col}"
      mo = get_modelinfo(col, @session)
      articles[col] = if mo != '' then mo else NOMODELINFO end
      @narticle += 1
      if mo != '' then mo else NOMODELINFO end
    end
    modellist[model] = true if model != NOMODELINFO
  end

  models = modellist.keys

  nextmodels = Array.new
  nextarticles = Hash.new
  nextmodels, nextarticles = scrape_collection(url, page + 1) if @narticle < MAXARTICLES

  #return models.merge(nextmodels), articles.merge(nextarticles)
  return models + nextmodels, articles.merge(nextarticles)
end

def main
  option = init
  begin
    STDERR.puts("SELECTION: #{@select}")
    @narticle = 0
    models, articles = case @select 
      when /^models/
        scrape_models(@site_url + @select, 1)
      when /^tag/ || /^collection/
        scrape_collection(@site_url + @select, 1)
      else
        scrape_collection(@site_url + @select, 1)
      end

    STDERR.puts "NMODELS: #{models.size}"

    modelinfo = Hash.new
    models.shuffle.each do |mo|
      break if articles.size >= MAXARTICLES
      #STDERR.puts "MOD: #{models[mo][1]} / #{articles.size}"
      begin
        if modelinfo[mo] == nil
          artist_id, mname, mcode, act = get_model(mo)
          modelinfo[mo] = [artist_id, mname, mcode, act] if act == true
        end  
        next if modelinfo[mo] == nil
      rescue => e
        STDERR.puts "ERROR scrape_modelpage: #{e}/#{mo}"
      end

      @nmodelpage = 0
      articles0, act = scrape_modelpage(mo, 1)
      next if act == false

      articles0.each do |ar|
        break if articles.size >= MAXARTICLES
        articles[ar] = mo
      end
    end

    STDERR.puts "ARTICLES: #{articles.size}"

    articles.each.with_index(1) do |(ar, mo), i|
      STDERR.print "ARTICLE(#{i}/#{MAXARTICLES}): "
      if mo == NOMODELINFO
        st = download_article(ar, nil, nil, nil, false)
        next
      end
      if modelinfo[mo] == nil
        artist_id, mname, mcode, act = get_model(mo)
        modelinfo[mo] = [artist_id, mname, mcode, act] # if act == true
      end
      #STDERR.puts "MO: #{modelinfo[mo]}/ #{mo}"
      # 黒人はこの時点でスキップされるのでarticle URLが記録されない。
      #next if modelinfo[mo] == nil

      model = modelinfo[mo]
      artist_id = model[0]
      mname = model[1]
      mcode = model[2]
      mact  = model[3]
      st = download_article(ar, artist_id, mname, mcode, mact)
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

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

USAGE = "eliteload.rb <YAML config> [<url of list>]"
DEBUG = true
TIMEOUT = 300
MAXMODELPAGES = 10
MAXARTICLES = 50
MAXMODELARTICLES = 5
RETRY = 20
INFOFILE = '_info.txt'

def init
  if ARGV.size < 1 || ARGV.size > 2
    STDERR.puts USAGE
    exit 1
  end

  $PARAM = load_config(ARGV[0])

  @db = EpTank.new($PARAM['database'])
  @session = WebSession.new(WebSession::WITHSCR, $PARAM['chromprofile'])
  @tankdir = "#{$PARAM['eptank']['dir']}#{$PARAM['elite']['site']}/"
  @tmpdir = $PARAM['eptank']['tmpdir']

  begin
    STDERR.puts "SITE: #{$PARAM['elite']['select']}"
    @site_id, @site_url = @db.get_site_info($PARAM['elite']['site'])
    STDERR.puts "ID|URL: #{@site_id}|#{@site_url}"
    @topurl = @site_url + $PARAM['elite']['select']
  rescue => e
  end

  return ARGV[1]

end

def load_image(url)
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
      File.open("#{@tmpdir}#{dname}/#{INFOFILE}", 'w') do |fp|
        fp.puts "model: #{mname}"
        fp.puts "title: #{title}"
      end
      zfp.add(INFOFILE, "#{@tmpdir}#{dname}/#{INFOFILE}")
      images.each do |im|
        fname = "#{bnum}-" + File.basename(im)
        File.open("#{@tmpdir}#{dname}/#{fname}", 'w') do |fp|
          charset, body = load_image(im)
          if body != nil
            fp.write(body)
          end
        end
        info = get_image_info("#{@tmpdir}#{dname}/#{fname}")
        #STDERR.puts "FNAME: #{info[0]}, FMT: #{info[2]}"
        zfp.add(fname, "#{@tmpdir}#{dname}/#{fname}")
        imginfo << info
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
  images = []
  title, images = get_images(url, @session)

  puts "TITLE: #{title}"
  return title, images
end

def regist_article(url, artist_id, mname, title, cbzfile, imginfo)
  STDERR.puts "URL: #{url}"
  STDERR.puts "MODEL: #{mname} (#{imginfo.size} images)"
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

def scrape_modelpage(url, pg)
  url = "#{url}/mpage/#{pg}/" if pg > 1
  articles = Array.new
  @session.navigate(url, 2)
  mname = ''
  begin
    chk = check_tags(@session)
    return '', [] if chk == false

    mcode = url.split("/")[-1]
    mname = get_modelname(@session) + "(#{mcode})"
    ars0 = get_articles(@session)
  rescue => e
    STDERR.puts "SCRAPE MODELPAGE ERROR: #{e}"
  end

  ars0.each do |ar|
    break if @narticle >= MAXARTICLES
    break if @nmodelpage >= MAXMODELARTICLES

    puts "AR: #{ar}"
    if @db.exist_article?(ar) || ar =~ /video/
      STDERR.puts "The Article is already exist: #{ar}"
    else
      articles << ar
      @narticle += 1
      @nmodelpage += 1
    end
  end
  articles2 = []
  if @narticle < MAXARTICLES

    #//*[@id="content"]/nav/ul/li[2]
    #//*[@id="content"]/nav/ul/li[3]
    #//*[@id="content"]/nav/ul/li[3]
    begin
      ele = @session.element('//*[@id="content"]/nav/ul/li[3]', 0)
      if ele != nil
        mn, articles2 = scrape_modelpage(url, pg + 1)
      end
    rescue StandardError => e
    end
  end
  return mname, articles + articles2
end

def scrape_models(url, page)
  models = []
  return models if page > MAXMODELPAGES || page < 1

  url2 = "#{url}page/#{page}/"
  models = get_models(url2, @session)
  nextmodels = scrape_models(url, page + 1)

  models + nextmodels
end

def main
  option = init
  @narticle = 0
  begin
    models = scrape_models(@topurl, 1)
    puts "NMODELS: #{models.size}"

    models.shuffle.each do |mo|
      break if @narticle >= MAXARTICLES
      @nmodelpage = 0
      mname, articles = scrape_modelpage(mo, 1)
      artist_id = @db.add_artist(mname, true)
      @db.commit if artist_id != nil
      STDERR.puts "ARTIST: #{artist_id} / #{mname}"
      articles.each do |ar|
        title, images = scrape_article(ar)
        if images[0] =~ /javascript/ || images.size < 5 
          STDERR.puts "IMGVDO: #{images}"
        else
          cbzfile, imginfo = create_cbz(mname, title, images)
          regist_article(ar, artist_id, mname, title, cbzfile, imginfo)
        end
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

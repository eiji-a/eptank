#!/usr/bin/ruby
#
# Elite Library
#


def get_images(url, session)
  #session.navigate(url, 3)

  title = "NO TITLE"
  image_urls = Array.new
  begin
    isvideo = session.element('/html/body', 0).attribute('class')
    '/html/head/title'
    if isvideo == 'page-video'
      t = session.text('//*[@id="root"]/section[1]/main/header/h1', 0)
      return t, [], false
    end
    title = session.text('//*[@id="top"]/h1', 0)
    #title = session.element("/html/head/title", 3).text
  rescue => e
    STDERR.puts "get_images: title: #{e}"
  end

  begin
    elems = session.elements('//*[@id="content"]/ul[1]/li/a', 0)
    elems.each do |el|
      image_urls << el.attribute('href')
    end
  rescue => e
    STDERR.puts "get_images: images: #{e}"
  end

  return title, image_urls, true
end

def get_articles(session)
  articles = Array.new
  begin
    elems = session.elements('//*[@id="content"]/ul/li/figure/a[1]', 0)
    #STDERR.puts "NELEMS: #{elems.size}"
    elems.each do |el|
      #STDERR.puts "GA: #{el.attribute('href')}"
      articles << el.attribute('href')
    end
  rescue => e
    STDERR.puts "get_articles: article: #{e}"
  end

  articles
end

def get_modelinfo(url, session)
  model = ''
  session.navigate(url, 1)
  begin
    elems = session.elements('//*[@id="content"]/p[2]/a', 0)
    elems.each do |el|
      mlink = el.attribute('href')
      if mlink =~ /model/
        model = mlink
        break
      end
    end
  rescue => e
    #
  end
  return model if model != ''

  begin
    elems = session.elements('//*[@id="content"]/p[1]/a', 0)
    elems.each do |el|
      mlink = el.attribute('href')
      if mlink =~ /model/
        model = mlink
        break
      end
    end
  rescue => e
    # no model information
  end

  # XEROTICA link
  #//*[@id="root"]/section[1]/main/header/ul/li[1]/a
  #//*[@id="root"]/section[1]/main/header/ul/li[1]/a

  #STDERR.puts "MODELINFO: get_modelinfo: #{model}"
  model
end

def get_models(url, session)
  session.navigate(url, 3)
  models = Array.new
  begin
    elems = session.elements('//*[@id="content"]/ul/li/figure/a', 0)
    elems.each do |el|
      models << el.attribute('href')
    end
  rescue => e
    STDERR.puts "get_models: model: #{e}"
  end
  return models
end

def get_collection(url, session)
  session.navigate(url, 3)
  cols = Array.new
  #STDERR.puts "COLERR: #{cols.size} / #{url}"
  begin
    #elems = session.elements('//*[@id="content"]/ul/li/figure/a', 0)
    elems = session.elements('/html/body/div/main/ul/li/figure/a[1]', 0)
    elems.each do |el|
      cols << el.attribute('href')
    end
  rescue => e
    STDERR.puts "get_collection: #{e}/#{url}"
  end
  #STDERR.puts "COLERR: #{cols.size} / #{url}"
  cols
end

def check_tags(session)
  elems = Array.new
  begin
    elems = session.elements('//*[@id="content"]/p/a', 0)
  rescue => e
    STDERR.puts "check_tags(1): #{e}"
  end
  elems.each do |el|
    return false if el.text == 'Ebony'
  end
  begin
    elems = session.elements('//*[@id="content"]/p[1]/a', 0)
  rescue => e
    STDERR.puts "check_tags(2): #{e}"
  end
  elems.each do |el|
    return false if el.text == 'Ebony'
  end
  true
end

def get_modelname(session)
  name = ""
  begin
    name = session.text('//*[@id="content"]/article/header/h1', 0)
  rescue
    # 
  end
  name
end

#---

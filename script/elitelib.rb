#!/usr/bin/ruby
#
# Elite Library
#


def get_images(url, session)
  session.navigate(url, 3)

  title = "NO TITLE"
  image_urls = Array.new
  begin
    isvideo = session.element('/html/body', 0).attribute('class')
    '/html/head/title'
    return '', [] if isvideo == 'page-video'
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

  return title, image_urls
end

def get_articles(session)
  articles = Array.new
  begin
    elems = session.elements('//*[@id="content"]/ul/li/figure/a', 0)
    elems.each do |el|
      articles << el.attribute('href')
    end
  rescue => e
    STDERR.puts "get_articles: article: #{e}"
  end

  articles
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

def check_tags(session)
  scrape = true
  begin
    elems = session.elements('//*[@id="content"]/p/a', 0)
    elems.each do |el|
      #puts "TAG: #{el.text}"
      if el.text == 'Ebony'
        scrape = false
        break
      end
      #scrape = true if el.text == 'Big Boobs'
    end
  end
  scrape
end

def get_modelname(session)
  name = ""
  begin
    name = session.text('//*[@id="content"]/article/header/h1', 0)
  end
  name
end

#---

#!/usr/bin/ruby
#
# PIXIV library
#


def getinfo_artwork(url, session)
  # 対象ページへ遷移
  session.navigate(url, 3)

  artist_id = ''
  artist_nm = ''
  title = 'NO TITLE'

  begin
    artist_id = session.attribute('href', '//*[@id="root"]/div[2]/div/div[3]/div/div/div[1]/aside/section[1]/h2/div/div/a').split("/")[-1]
    artist_nm = session.text('//*[@id="root"]/div[2]/div/div[3]/div/div/div[1]/aside/section[1]/h2/div/div/a/div', 0)
    title     = session.text('//*[@id="root"]/div[2]/div/div[3]/div/div/div[1]/main/section/div[1]/div/figcaption/div/div/h1', 0)
  rescue => e
    STDERR.puts "LPS ERROR: #{e}"
  end

  image_urls = Array.new
  begin
    begin
      # "すべて見る"ボタンをクリック
      session.click('//*[@id="root"]/div[2]/div/div[3]/div/div/div[1]/main/section/div[1]/div/div[4]/div/div[2]/button/div[2]', 3)

      elems = session.elements('//*[@id="root"]/div[2]/div/div[3]/div/div/div[1]/main/section/div[1]/div/figure/div[1]/div/div[2]/a')
      elems.each do |e|
        image_urls << e.attribute('href')
      end
    rescue => e
      image_urls << session.attribute('href', '//*[@id="root"]/div[2]/div/div[3]/div/div/div[1]/main/section/div[1]/div/figure/div[1]/div[1]/div/a', 0)
    end
  rescue => e
    STDERR.puts "PAGE NOT IMAGE?: #{e}" if DEBUG
    return nil, nil, '', ''
  end

  return artist_id, artist_nm, title, image_urls

end

def getinfo_illustration(url, session)
  session.navigate url

  article_urls = Array.new
  begin
    elems = session.elements('//*[@id="root"]/div[2]/div/div[3]/div/div/div[2]/div[3]/div/div/section/div[3]/div/ul/li/div/div[1]/div/a')
    elems.each do |e|
      aurl = e.attribute('href')
      article_urls << aurl
    end
  rescue => e
    STDERR.puts "ILLUSTRATION ERROR(1): #{e}"
  end

  nextbutton = nil
  begin
    nextbutton = session.element_nth("//*[@id=\"root\"]/div[2]/div/div[3]/div/div/div[2]/nav/a", -1, 2)
    nextbutton = nil if nextbutton.attribute('hidden') == 'true'
  rescue => e
    STDERR.puts "FOLLOWING ERROR(2): #{e}"
  end

  return article_urls, nextbutton
end

def getinfo_following(url, session)
  session.navigate url
  
  nfollow = 0
  curr_artists = Hash.new
  nextbutton = nil

  begin
    nfollow = session.text('//*[@id="root"]/div[2]/div/div[3]/div/div/div[2]/div[2]/div[2]/div/section/div[1]/div/div/div/span').to_i
    elems_id = session.elements('//*[@id="root"]/div[2]/div/div[3]/div/div/div[2]/div[2]/div[2]/div/section/div[2]/div/div/div[1]/div/a')
    elems_nm = session.elements('//*[@id="root"]/div[2]/div/div[3]/div/div/div[2]/div[2]/div[2]/div/section/div[2]/div/div/div[1]/div/a/div')
    elems_id.zip(elems_nm).each do |e|
      aid = e[0].attribute('data-gtm-value')
      anm = e[1].attribute('title')
      STDERR.puts "FOLLOWING: #{aid}/#{anm}" if DEBUG
      curr_artists[aid] = anm
    end
=begin
    elems.each do |e|
      aid = e.attribute('href').split("/")[-1]
      anm = e.text
      STDERR.puts "FOLLOWING: #{aid}/#{anm}" if DEBUG
      curr_artists[aid] = anm
    end
=end
  rescue => e
    STDERR.puts "FOLLOWING ERROR(1): #{e}"
  end

  begin
    nextbutton = session.element_nth("//*[@id=\"root\"]/div[2]/div/div[3]/div/div/div[2]/nav/a", -1)
    nextbutton = nil if nextbutton.attribute('hidden') == 'true'
  rescue => e
    STDERR.puts "FOLLOWING ERROR(2): #{e}"
  end

  return nfollow, curr_artists, nextbutton
end


#---

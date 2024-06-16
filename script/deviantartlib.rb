#!/usr/bin/ruby
#
# DeviantArt library
#


def getinfo_artwork(url, session)
  # 対象ページへ遷移
  session.navigate(url, 3)

  artist_id = ''
  artist_nm = ''
  title = 'NO TITLE'

  begin
    artist_id = session.attribute('href', '//*[@id="root"]/main/div/div[3]/div/div[1]/div/div[2]/div[2]/div/div[2]/a').split("/")[-1]
    artist_nm = session.text('//*[@id="root"]/main/div/div[3]/div/div[1]/div/div[2]/div[2]/div/div[2]/a/span[1]', 0)
    title     = session.text('//*[@id="root"]/main/div/div[3]/div/div[1]/div/div[2]/div[1]/h1', 0)
  rescue => e
    STDERR.puts "LPS ERROR: #{e}"
  end

  image_urls = Array.new
  begin
    # 画像をクリックして画像表示へ
    session.click('/html/body/div[1]/main/div/div[1]/div[1]/div/div/div[2]/img', 2)
    begin
      image_urls << session.attribute('src', '/html/body/div[5]/div/div/div/img')
    rescue => e
      image_urls << session.attribute('src', '//*[@id="root"]/main/div/div[1]/div[1]/div/div/div[2]/img')
    end
  rescue => e
    STDERR.puts "PAGE NOT IMAGE?: #{e}" if DEBUG
    return 0
  end

  return artist_id, artist_nm, title, image_urls

end

def getinfo_illustration(url, session)
  session.navigate url
  sleep 3

  article_urls = Array.new
  begin
=begin
    last_height = session.execute_script("return document.body.scrollHeight")
    while true
      1.step(last_height, last_height/10).each do |height|
        session.execute_script("window.scrollTo(0,#{height})")
      end
      sleep 1
      new_height = session.execute_script("return document.body.scrollHeight")
      if new_height == last_height
        break
      end
      last_height = new_height
    end
    sleep 20
=end
    # elems_link = session.elements('//*[@id="sub-folder-gallery"]/div/div[3]/div/div/div/div/div/div/a', 0) # OLD XPath
    elems_link = session.elements('//*[@id="sub-folder-gallery"]/div/div[2]/div[2]/div/div/div/div/div/div/a', 0)
    # elems_img  = session.elements('//*[@id="sub-folder-gallery"]/div/div[3]/div/div/div/div/div/div/a/div/img', 0) # OLD XPath
    elems_img  = session.elements('//*[@id="sub-folder-gallery"]/div/div[2]/div[2]/div/div/div/div/div/div/a/div/img', 0)
    STDERR.puts "NIMGS: #{elems_img.size}/#{elems_link.size}"
    elems_link.zip(elems_img) do |li, im|
      next if li == nil || im == nil
      #STDERR.puts "ELE: #{li.attribute('href')}, #{im}"
      STDERR.puts "UNLOCK!:#{im.attribute('src')}\nLINK: #{li.attribute('href')}" if im.attribute('src') =~ /blur_30/
      next if im.attribute('src') =~ /blur_30/
      article_urls << li.attribute('href')
    end
  rescue => e
    STDERR.puts "ILLUSTRATION ERROR(1): #{e}"
  end

  nextbutton = nil
=begin
  begin
    nextbutton = session.element_nth("//*[@id=\"root\"]/div[2]/div/div[3]/div/div/div[2]/nav/a", -1, 2)
    nextbutton = nil if nextbutton.attribute('hidden') == 'true'
  rescue => e
    STDERR.puts "FOLLOWING ERROR(2): #{e}"
  end
=end

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

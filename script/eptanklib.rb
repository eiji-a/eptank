#-- eptank library
#

require 'yaml'
require 'rubygems'
require 'selenium-webdriver'

# CLASSES

## Web Session

class WebSession

  HEADLESS = true
  WITHSCR  = !HEADLESS
  WAIT = 3
  TRY = 10
  PITCH = 0.5
  UA = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/115.0.0.0 Safari/537.36'

  def initialize(headless = false, profile = nil)
    @headless = headless

    # cf: https://qiita.com/kawagoe6884/items/cea239681bdcffe31828
    options = Selenium::WebDriver::Chrome::Options.new
    options.add_argument('--headless') if headless
    options.add_argument('--user-data-dir=/home/eiji/.config/google-chrome')
    options.add_argument('--profile-directory=Default')
    options.add_argument('--disable-blink-features=AutomationControlled')
    @session = Selenium::WebDriver.for :chrome, options: options
    #@session = Selenium::WebDriver.for :chrome, desired_capabilities: caps, http_client: Selenium::WebDriver::Remote::Http::Default.new
    @session.manage.window.maximize unless headless
    @wait = Selenium::WebDriver::Wait.new(:timeout => WAIT)
    @session.execute_script('const newProto = navigator.__proto__;delete newProto.webdriver;navigator.__proto__ = newProto;')
  end

  def quit
    @session.quit
  end

  def navigate(url, wait = WAIT)
    @session.navigate.to url
    sleep wait
  end

  def add_cookie(cookie)
    begin
      @session.manage.add_cookie(cookie)
    rescue => e
    end
  end

  def all_cookies
    @session.manage.all_cookies
  end

  def click(button, wait = WAIT)
    elem = if button.class == Selenium::WebDriver::Element
      button
    else
      element(button, 0)
    end
    elem.click
    sleep wait
  end

  def send_keys(val, xpath, wait = WAIT)
    #sleep wait
    elem = element(xpath, wait)
    elem.send_keys(val)
  end

  def attribute(attr, xpath, wait = WAIT)
    #sleep wait
    elem = element(xpath, wait)
    elem.attribute(attr) if elem != nil
  end

  def text(xpath, wait = WAIT)
    #sleep wait
    elem = element(xpath, wait)
    elem.text if elem != nil
  end

  def element(xpath, wait = WAIT)
    sleep wait
    #elem = nil
    #TRY.times do
    #  begin
        elem = @session.find_element(:xpath, xpath)
    #  rescue => e
    #    sleep PITCH
    #  end
    #end
    #@wait.until {elem.displayed?}
    elem if elem != nil
  end

  def elements(xpath, wait = WAIT)
    #sleep wait
    elems = nil
    TRY.times do
      begin
        elems = @session.find_elements(:xpath, xpath)
      rescue => e
        sleep PITCH
      end
    end
    elems if elems != nil
  end

  def element_nth(xpath, nth, wait = WAIT)
    sleep wait
    #elem = nil
    #TRY.times do
    #  begin
        elem = @session.find_elements(:xpath, xpath)[nth]
    #  rescue => e
    #    sleep PITCH
    #  end
    #end
    #@wait.until {elem.displayed?}
    elem if elem != nil
  end

end

class EpTank

  def initialize(database)
    begin
      # parameters
      #  host, socket, port, connect_timeout, database, flags, charset, connect_attrs
      #  get_server_public_key
      @db = Mysql.new(host:     database['host'], port:     database['port'],
                      username: database['user'], password: database['pass'],
                      database: database['name'], charset:  database['charset'])
      @db.connect
      @db.autocommit(false)
    rescue => e
      STDERR.puts "DB OPEN ERROR: #{e}"
      raise StandardError, e.to_s
    end
    @db
  end

  def close
    @db.close
  end

  def commit
    @db.commit
  end

  def rollback
    @db.rollback
  end

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
  
  def regist_post(site_id, title, artist_id, purl, post_time, ext, nimage)
    rc = false
    post_id = nil
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
      st.execute(title, purl, ext, nimage, post_time, true, site_id, aid)
      rc = true
      sql = <<-SQL
        SELECT id FROM article
        WHERE url = ?;
      SQL
      st = @db.prepare(sql)
      st.execute(purl).each do |a|
        post_id = a[0]
      end
    rescue => e
      STDERR.puts "REGIST POST ERROR: #{e}"
    end
    return rc, post_id
  end

  def update_post(purl, nimage)
    begin
      sql = <<-SQL
        UPDATE article SET nimage = ? WHERE url = ?;
      SQL
      st = @db.prepare(sql)
      st.execute(nimage, purl)
    rescue => e
      STDERR.puts "UPDATE POST ERROR: #{e}"
    end
  end

  def read_artist(site_id)
    artists = Hash.new
    begin
      sql = <<-SQL
        SELECT userid, username FROM enroll
        WHERE site_id = ? AND active = true;
      SQL
      st = @db.prepare(sql)
      st.execute(site_id).each do |uid, unm|
          artists[uid] = unm
          STDERR.puts "UID/UNM: #{uid}/#{unm}" if DEBUG
      end
    rescue => e
      STDERR.puts "READ ARTIST ERROR: #{e}"
    end
    STDERR.puts "READ ARTIST: #{artists.size} artists!" if DEBUG
    artists
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

  def update_artists(diff_artists)
    diff_artists.each do |k, v|
      STDERR.puts "ARTIST: #{k}/#{v.class}" if DEBUG
      begin
        ex, act = exist_artist?(k)
        if ex == true #
          if v == nil
            STDERR.puts "ARTIST DELETE: #{k}"
            sql = <<-SQL
              UPDATE enroll SET active = false WHERE userid = ?;
            SQL
            st = @db.prepare(sql)
            st.execute(k)
            @db.commit
          else
            sql = <<-SQL
              UPDATE enroll SET active = true WHERE userid = ?;
            SQL
            st = @db.prepare(sql)
            st.execute(k)
            @db.commit
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
  
end


# UTILITIES

def load_config(cfile)
  if File.exist?(cfile) == false
    raise StandardError, "Config file not found: #{cfile}"
  end
  param = File.open(cfile, 'r') do |fp|
    YAML.load(fp)
  end
  param
end


#---

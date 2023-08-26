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
  WAIT = 5

  def initialize(headless = false)
    @headless = headless
    @session = if headless
      options = Selenium::WebDriver::Chrome::Options.new
      options.add_argument('--headless')
      Selenium::WebDriver.for :chrome,options: options
    else
      Selenium::WebDriver.for :chrome
    end
    @session.manage.window.maximize unless headless
  end

  def navigate(url)
    @session.navigate.to url
  end

  def click(xpath, wait = WAIT)
    sleep wait
    elem = @session.find_element(:xpath, xpath)
    elem.click
  end

  def send_keys(val, xpath, wait = WAIT)
    sleep wait
    elem = @session.find_element(:xpath, xpath)
    elem.send_keys(val)
  end

  def attribute(attr, xpath, wait = WAIT)
    sleep wait
    elem = @session.find_element(:xpath, xpath)
    elem.attribute(attr)
  end

  def element_nth(xpath, nth, wait = WAIT)
    sleep wait
    @session.find_elements(:xpath, xpath)[nth]
  end

  def text(xpath, wait = WAIT)
    sleep wait
    elem = @session.find_element(:xpath, xpath)
    elem.text
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

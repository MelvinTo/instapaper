#!/usr/bin/env ruby

# this script is used to 
# 1. get an average usage of instapaper
# 2. produce an xml file containing all downloaded instapaper texts

require 'rubygems'
require 'instapaper'
require 'logger'
require 'yaml'
require 'pp'
require 'builder'
require 'rexml/document'
require 'rexml/xpath'
require 'nokogiri'

config_hash = YAML.load(File.read("./instapaper.yaml"))

logger = Logger.new(STDOUT)

Instapaper.configure do |config|
  config.consumer_key = config_hash["oauth"]["consumer_key"]
  config.consumer_secret = config_hash["oauth"]["consumer_secret"]
end

username = config_hash["account"]["username"]
password = config_hash["account"]["password"]
limit = config_hash["setting"]["limit"]
token = Instapaper.access_token( username, password )

Instapaper.configure do |config|
  config.oauth_token = token["oauth_token"]
  config.oauth_token_secret = token["oauth_token_secret"]
end

identities = Instapaper.verify_credentials

logger.info("Logged in , my user id is #{identities[0]["username"]}")

unread_bookmarks = Instapaper.bookmarks({"limit" => limit})
archive_bookmarks = Instapaper.bookmarks({"folder_id" => "archive", "limit"=>limit})
starred_bookmarks = Instapaper.bookmarks({"folder_id" => "starred", "limit"=>limit})

def get_bookmarks_in_range(bookmarks, range)
  now = Time.new.to_i
  timestamp_limit = now - range
  
  bookmarks.select { |bookmark|
    bookmark.time > timestamp_limit
  }
end

def product_xml(bookmarks)
  xml = Builder::XmlMarkup.new(:indent => 2)
  xml.instruct! :xml, :encoding => "ASCII"
  
  xml.searchresult do |p|
    p.query("text")
    bookmarks.each do |bookmark|
      id = bookmark["bookmark_id"]
      title = bookmark["title"]
      text = bookmark["text"]
      url = bookmark["url"]
      
      p.document("id" => id) do |pp|
        pp.title title
        pp.snippet text
        pp.url url
      end
    end
  end
end

def get_text(bookmark_id)
  text = Instapaper.text(bookmark_id)
  return text
end

# assume limit 500 covers the timestamp limit, because 500 is hard limit at instapaper server side
unread_bookmarks_in_range = get_bookmarks_in_range(unread_bookmarks, config_hash["setting"]["range"])
archive_bookmarks_in_range = get_bookmarks_in_range(archive_bookmarks, config_hash["setting"]["range"])
starred_bookmarks_in_range = get_bookmarks_in_range(starred_bookmarks, config_hash["setting"]["range"])

num_of_added_articles = unread_bookmarks_in_range.size + archive_bookmarks_in_range.size
# + starred_bookmarks_in_range.size
num_of_readed_articles = archive_bookmarks_in_range.size 
#+ starred_bookmarks_in_range.size

logger.info("Added #{num_of_added_articles * 60 * 60 * 24 * 365 / config_hash["setting"]["range"] / 12} articles per month")
logger.info("Readed #{num_of_readed_articles * 60 * 60 * 24 * 365 / config_hash["setting"]["range"] / 12} articles per month")

unread_bookmarks_in_range.each do |article|
  text = get_text(article["bookmark_id"])
  real_texts = ""
  html_doc = Nokogiri::HTML(text)
  html_doc.xpath("//p").each do |element|
    real_texts << element.text.to_s
    real_texts << "\n"
  end
  
  article["text"] = real_texts
end

text_xml = product_xml(unread_bookmarks_in_range)

File.open("output.xml", 'w') {|f| f.write(text_xml) }


#count_hash = {}
#
#
#all_bookmarks = bookmarks + archive_bookmarks + starred_bookmarks
#
#all_bookmarks.each do |bookmark|
#  title = bookmark.title
#  url = bookmark.url
#  timestamp = Time.at(bookmark.time)
#  
#  yearmonth = timestamp.year.to_s + "%02d" % timestamp.month
#  
#  if ! count_hash.has_key? yearmonth
#    count_hash[yearmonth] = 0
#  end
#  
#  count_hash[yearmonth] += 1 
#end
#
#pp count_hash
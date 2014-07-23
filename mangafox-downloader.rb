require 'nokogiri'
require 'open-uri'

def read_url url
  Nokogiri::XML(open(url).read)
end

def get_base_url_chapter url
  "#{url.split('/')[0...-1].join('/')}/"
end

Dir.mkdir('Death Note') unless File.exists?("Death Note")

manga = Nokogiri::XML(open('http://mangafox.me/manga/death_note/').read)

manga.css('.chlist li').reverse.each do |chapter|
  name = chapter.css('.tips')[0].children[0].text
  Dir.mkdir("Death Note/#{name}") unless File.exists?("Death Note/#{name}")
  
  chapter = chapter.css('.tips')[0].attributes["href"].value
  base_url_chapter = get_base_url_chapter chapter
  flux = read_url "#{base_url_chapter}1.html"
  flux.css('#top_center_bar .l select option')[0...-1].each do |option|
    
    page = read_url "#{base_url_chapter}#{option.attributes["value"].value}.html"
    
    src = page.css('#viewer img#image')[0].attributes["src"].value
    extension = src.split('.')[src.split('.').count - 1]

    open("Death Note/#{name}/page-#{option.attributes["value"].value}.#{extension}",'wb') do |file|
      p file
      file << open(src).read
    end

  end
end
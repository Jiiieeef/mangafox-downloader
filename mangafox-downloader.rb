require 'nokogiri'
require 'open-uri'

def read_url url
  Nokogiri::XML(open(url).read)
end

flux = read_url "http://mangafox.me/manga/death_note/v13/c110.5/1.html"
flux.css('#top_center_bar .l select option')[0...-1].each do |option|
  
  page = read_url "http://mangafox.me/manga/death_note/v13/c110/#{option.attributes["value"].value}.html"
  
  src = page.css('#viewer img#image')[0].attributes["src"].value
  extension = src.split('.')[src.split('.').count - 1]

  open("page-#{option.attributes["value"].value}.#{extension}",'wb') do |file|
    p file
    file << open(src).read
  end

end

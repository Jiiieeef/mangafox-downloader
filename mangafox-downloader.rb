require 'nokogiri'
require 'open-uri'

flux = Nokogiri::XML(open("http://mangafox.me/manga/death_note/v13/c110.5/1.html").read)
flux.css('#top_center_bar .l select option')[0...-1].each do |option|
  
  page = Nokogiri::XML(open("http://mangafox.me/manga/death_note/v13/c110/#{option.attributes["value"].value}.html").read)
  
  src = page.css('#viewer img#image')[0].attributes["src"].value
  extension = src.split('.')[src.split('.').count - 1]

  open("page-#{option.attributes["value"].value}.#{extension}",'wb') do |file|
    p file
    file << open(src).read
  end

end

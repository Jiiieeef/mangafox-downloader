require 'nokogiri'
require 'open-uri'
require 'terminal-notifier'

def read_url url
  Nokogiri::XML(open(url).read)
end

def get_base_url_chapter url
  "#{url.split('/')[0...-1].join('/')}/"
end

mangas = ARGV

mangas.each do |manga|

  manga_slug = manga.gsub(/\s+/, "_").downcase
  manga_html = read_url "http://mangafox.me/manga/#{manga_slug}"

  chapters = manga_html.css('.chlist li')

  if chapters.count > 0

    Dir.mkdir(manga) unless File.exists?(manga)

    chapters.reverse.each do |chapter|
      name = chapter.css('.tips')[0].children[0].text
      Dir.mkdir("#{manga}/#{name}") unless File.exists?("#{manga}/#{name}")
      
      chapter = chapter.css('.tips')[0].attributes["href"].value
      base_url_chapter = get_base_url_chapter chapter
      flux = read_url "#{base_url_chapter}1.html"
      flux.css('#top_center_bar .l select option')[0...-1].each do |option|
        
        page = read_url "#{base_url_chapter}#{option.attributes["value"].value}.html"
        
        src = page.css('#viewer img#image')[0].attributes["src"].value
        extension = src.split('.')[src.split('.').count - 1]

        open("#{manga}/#{name}/page-#{option.attributes["value"].value}.#{extension}",'wb') do |file|
          p file
          file << open(src).read
        end
      end
    end
    TerminalNotifier.notify("Download of \"#{manga}\" is over.", title: 'MangaFox Downloader', sound: 'default')
  else
    p "#{manga} not found :("
  end
end
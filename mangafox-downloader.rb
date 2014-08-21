require 'nokogiri'
require 'open-uri'
require 'terminal-notifier'
require 'zip'

def read_url url
  Nokogiri::XML(open(url).read)
end

def get_base_url_chapter url
  "#{url.split('/')[0...-1].join('/')}/"
end

def slugify manga
  slug = manga.gsub(/[\s+.!'"-]/, "_").downcase
  slug = slug[0...-1] if slug[slug.size - 1] == "_"
  slug
end

def zip_chapter pages, path_to_pages
  Zip::File.open("#{path_to_pages}.cbz", Zip::File::CREATE) do |zipfile|
    pages.each do |filename|
      zipfile.add(filename.split('/').last, filename)
    end
    p "#{path_to_pages} is zipped"
  end
end

Dir.mkdir("Downloads") unless Dir.exist?("Downloads")

mangas = ARGV

mangas.each do |manga|

  manga_slug = slugify manga
  manga_html = read_url "http://mangafox.me/manga/#{manga_slug}"

  chapters = manga_html.css('.chlist li')

  if chapters.count > 0

    Dir.mkdir("Downloads/#{manga}") unless File.exist?("Downloads/#{manga}")

    chapters.reverse.each do |chapter|
      name = chapter.css('.tips')[0].children[0].text
      title = chapter.css('.title')[0].children[0].text
      name += " - #{title}" unless title.nil?
      Dir.mkdir("Downloads/#{manga}/#{name}") unless File.exist?("Downloads/#{manga}/#{name}")
      
      chapter = chapter.css('.tips')[0].attributes["href"].value
      base_url_chapter = get_base_url_chapter chapter
      flux = read_url "#{base_url_chapter}1.html"
      flux.css('#top_center_bar .l select option')[0...-1].each do |option|
        
        page = read_url "#{base_url_chapter}#{option.attributes["value"].value}.html"
        
        src = page.css('#viewer img#image')[0].attributes["src"].value
        extension = src.split('.')[src.split('.').count - 1]

        open("Downloads/#{manga}/#{name}/page-#{option.attributes["value"].value}.#{extension}",'wb') do |file|
          p file
          file << open(src).read
        end
      end
      zip_chapter Dir["Downloads/#{manga}/#{name}/*"], "Downloads/#{manga}/#{name}"
    end
    TerminalNotifier.notify("Download of \"#{manga}\" is over.", title: 'MangaFox Downloader', sound: 'default')
  else
    p "#{manga} not found :("
  end
end
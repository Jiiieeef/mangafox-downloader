require 'nokogiri'
require 'open-uri'
require 'terminal-notifier'
require 'zip'
require 'yaml'

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
  FileUtils.rm_rf("#{path_to_pages}.cbz") if File.exist?("#{path_to_pages}.cbz")
  Zip::File.open("#{path_to_pages}.cbz", Zip::File::CREATE) do |zipfile|
    pages.each do |filename|
      zipfile.add(filename.split('/').last, filename)
    end
    p "#{path_to_pages} is zipped"
  end
  FileUtils.rm_rf("#{path_to_pages}") if $config["zip"]["delete_folders_after_archive"]
end

$config = YAML.load_file('config.yml')
download_path = $config["path_to_create"]

Dir.mkdir(download_path) unless Dir.exist?(download_path)

mangas = ARGV

mangas.each do |manga|

  manga_slug = slugify manga
  manga_html = read_url "http://mangafox.me/manga/#{manga_slug}"

  chapters = manga_html.css('.chlist li')

  if chapters.count > 0

    Dir.mkdir("#{download_path}/#{manga}") unless File.exist?("#{download_path}/#{manga}")

    chapters.reverse.each do |chapter|
      name = chapter.css('.tips')[0].children[0].text
      title = chapter.css('.title')[0].children[0].text
      name += " - #{title}" unless title.nil?
      Dir.mkdir("#{download_path}/#{manga}/#{name}") unless File.exist?("#{download_path}/#{manga}/#{name}")
      
      chapter = chapter.css('.tips')[0].attributes["href"].value
      base_url_chapter = get_base_url_chapter chapter
      flux = read_url "#{base_url_chapter}1.html"
      flux.css('#top_center_bar .l select option')[0...-1].each do |option|
        
        page = read_url "#{base_url_chapter}#{option.attributes["value"].value}.html"
        
        src = page.css('#viewer img#image')[0].attributes["src"].value
        extension = src.split('.')[src.split('.').count - 1]

        open("#{download_path}/#{manga}/#{name}/page-#{option.attributes["value"].value}.#{extension}",'wb') do |file|
          p file
          file << open(src).read
        end
      end
      zip_chapter Dir["#{download_path}/#{manga}/#{name}/*"], "#{download_path}/#{manga}/#{name}" if $config["zip"]["should_archive"]
    end
    TerminalNotifier.notify("Download of \"#{manga}\" is over.", title: 'MangaFox Downloader', sound: 'default') if $config["notification"]["should_notify"]
  else
    p "#{manga} not found :("
  end
end
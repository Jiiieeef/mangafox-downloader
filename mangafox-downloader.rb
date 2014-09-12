require 'nokogiri'
require 'open-uri'
require 'terminal-notifier'
require 'zip'
require 'yaml'
require './classes'

def read_url url
  Nokogiri::XML(open(url).read)
end

def get_base_url_chapter url
  "#{url.split('/')[0...-1].join('/')}/"
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

manga = Manga.new ARGV[0]
manga_html = read_url "http://mangafox.me/manga/#{manga.name_slugified}"

chapters = manga_html.css('.chlist li')

if chapters.count > 0

  chapters.reverse.each do |chapter|

    name = chapter.css('.tips')[0].children[0].text
    if chapter.css('.title').size > 0
      title = chapter.css('.title')[0].children[0].text
      name += " - #{title}"
    end
    
    chapter = chapter.css('.tips')[0].attributes["href"].value
    base_url_chapter = get_base_url_chapter chapter
    chapter = Chapter.new name, base_url_chapter

    flux = read_url "#{base_url_chapter}1.html"
    flux.css('#top_center_bar .l select option')[0...-1].each do |option|
      
      page = read_url "#{base_url_chapter}#{option.attributes["value"].value}.html"
      url_image = page.css('#viewer img#image')[0].attributes["src"].value
      extension = url_image.split('.')[url_image.split('.').count - 1]
      
      page = Page.new url_image, "Downloads/#{manga.name}/#{name}/page-#{option.attributes["value"].value}.#{extension}"
      chapter.pages << page
    end
    manga.chapters << chapter

  end
  Dir.mkdir("#{download_path}/#{manga.name}") unless File.exists?("#{download_path}/#{manga.name}")
  manga.chapters.each do |chapter|
    Dir.mkdir("#{download_path}/#{manga.name}/#{chapter.name}") unless File.exists?("#{download_path}/#{manga.name}/#{chapter.name}")
    chapter.pages.each_with_index do |page, index|
      open(page.path_image,'wb') do |file|
       p file
       file << open(page.url_image).read
     end
    end
    zip_chapter Dir["#{download_path}/#{manga.name}/#{chapter.name}/*"], "#{download_path}/#{manga.name}/#{chapter.name}" if $config["zip"]["should_archive"]
  end
  TerminalNotifier.notify("Download of \"#{manga.name}\" is over.", title: 'MangaFox Downloader', sound: 'default') if $config["notification"]["should_notify"]
else
  p "#{manga} not found :("
end
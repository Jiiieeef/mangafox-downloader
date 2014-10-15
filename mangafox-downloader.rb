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
  p "But I will do a research for you ;)"

  encoded_name = URI.encode manga.name
  search_result = read_url("http://mangafox.me/search.php?name_method=cw&name=#{encoded_name}&type=&author_method=cw&author=&artist_method=cw&artist=&genres%5BAction%5D=0&genres%5BAdult%5D=0&genres%5BAdventure%5D=0&genres%5BComedy%5D=0&genres%5BDoujinshi%5D=0&genres%5BDrama%5D=0&genres%5BEcchi%5D=0&genres%5BFantasy%5D=0&genres%5BGender+Bender%5D=0&genres%5BHarem%5D=0&genres%5BHistorical%5D=0&genres%5BHorror%5D=0&genres%5BJosei%5D=0&genres%5BMartial+Arts%5D=0&genres%5BMature%5D=0&genres%5BMecha%5D=0&genres%5BMystery%5D=0&genres%5BOne+Shot%5D=0&genres%5BPsychological%5D=0&genres%5BRomance%5D=0&genres%5BSchool+Life%5D=0&genres%5BSci-fi%5D=0&genres%5BSeinen%5D=0&genres%5BShoujo%5D=0&genres%5BShoujo+Ai%5D=0&genres%5BShounen%5D=0&genres%5BShounen+Ai%5D=0&genres%5BSlice+of+Life%5D=0&genres%5BSmut%5D=0&genres%5BSports%5D=0&genres%5BSupernatural%5D=0&genres%5BTragedy%5D=0&genres%5BWebtoons%5D=0&genres%5BYaoi%5D=0&genres%5BYuri%5D=0&released_method=eq&released=&rating_method=eq&rating=&is_completed=&advopts=1")
  search_result.css('#listing tr:not(:first)').each do |result|
    p result.css('td:first a').text
  end
end
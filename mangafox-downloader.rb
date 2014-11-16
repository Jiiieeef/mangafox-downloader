require 'nokogiri'
require 'open-uri'
require 'terminal-notifier'
require 'zip'
require 'yaml'
require 'highline/import'
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

def name_slugified name
  slug = name.gsub(" - ","_").gsub(/[\s+.^!'"-:\/]/, "_").downcase
  slug = slug[0...-1] if slug[slug.size - 1] == "_"
  slug
end

def thread_action chapters, &block
  queue = Queue.new
  chapters.map { |arr| queue << arr }

  threads = $config["parallel_thread"].times.map do
    Thread.new do
      while !queue.empty? && chapter = chapters.pop
        yield(chapter)
      end
    end
  end
  threads.each(&:join)
end

def download_manga manga_name, manga_name_slugified

  download_path = $config["path_to_create"]
  Dir.mkdir(download_path) unless Dir.exist?(download_path)

  manga = Manga.new manga_name
  manga_html = read_url "http://mangafox.me/manga/#{manga_name_slugified}"

  p "Choose if you want to download all volumes or only one:"
  manga_html.css('.volume').reverse.each_with_index do |volume, index|
    p "#{index + 1}. #{volume.text}"
  end
  p "#{manga_html.css('.volume').size + 1}. All volumes"
  input = ask("Which one must I download ? (set number) :", Integer) { |i| i.in = 1..(manga_html.css('.volume').size + 1) }
  if input == (manga_html.css('.volume').size + 1)
    p "All volumes"
    chapters = manga_html.css('.chlist li')
  else
    p "Volume #{input}"
    chapters = manga_html.css(".chlist").reverse[input - 1].css('li')
  end

  thread_action chapters do |chapter|
    name = chapter.css('.tips')[0].children[0].text
    
    chapter = chapter.css('.tips')[0].attributes["href"].value
    base_url_chapter = get_base_url_chapter chapter
    chapter = Chapter.new name, base_url_chapter

    flux = read_url "#{base_url_chapter}1.html"
    flux.css('#top_center_bar .l select option')[0...-1].each do |option|
      begin
        page = read_url "#{base_url_chapter}#{option.attributes["value"].value}.html"
        url_image = page.css('#viewer img#image')[0].attributes["src"].value
        extension = url_image.split('.')[url_image.split('.').count - 1]
        
        page = Page.new url_image, "Downloads/#{manga.name}/#{name}/page-#{option.attributes["value"].value}.#{extension}"
        chapter.pages << page
      rescue
        p "----------------------------------"
        p "#{base_url_chapter}#{option.attributes["value"].value}.html has fail"
        p "----------------------------------"
      end
    end
    manga.chapters << chapter
  end

  Dir.mkdir("#{download_path}/#{manga.name}") unless File.exists?("#{download_path}/#{manga.name}")
  thread_action manga.chapters do |chapter|
    Dir.mkdir("#{download_path}/#{manga.name}/#{chapter.name}") unless File.exists?("#{download_path}/#{manga.name}/#{chapter.name}")
    chapter.pages.each_with_index do |page, index|
      begin
        open(page.path_image,'wb') do |file|
         p file
         file << open(page.url_image).read
        end
      rescue
        p "========================================="
        p "#{page.path_image} has fail"
        p "========================================="
      end
    end
    zip_chapter Dir["#{download_path}/#{manga.name}/#{chapter.name}/*"], "#{download_path}/#{manga.name}/#{chapter.name}" if $config["zip"]["should_archive"]
  end

  TerminalNotifier.notify("Download of \"#{manga.name}\" is over.", title: 'MangaFox Downloader', sound: 'default') if $config["notification"]["should_notify"]
end

$config = YAML.load_file('config.yml')

manga_name = ARGV[0]
manga_name_slugified = name_slugified(manga_name)
manga_html = read_url "http://mangafox.me/manga/#{name_slugified(manga_name)}"

if manga_html.css('#searchform').size == 0
  download_manga manga_name, manga_name_slugified
else
  p "#{manga_name} not found :(\nBut I will do a research for you ;)"
  
  encoded_name = URI.encode manga_name
  search_result = read_url("http://mangafox.me/search.php?name_method=cw&name=#{encoded_name}&type=&author_method=cw&author=&artist_method=cw&artist=&genres%5BAction%5D=0&genres%5BAdult%5D=0&genres%5BAdventure%5D=0&genres%5BComedy%5D=0&genres%5BDoujinshi%5D=0&genres%5BDrama%5D=0&genres%5BEcchi%5D=0&genres%5BFantasy%5D=0&genres%5BGender+Bender%5D=0&genres%5BHarem%5D=0&genres%5BHistorical%5D=0&genres%5BHorror%5D=0&genres%5BJosei%5D=0&genres%5BMartial+Arts%5D=0&genres%5BMature%5D=0&genres%5BMecha%5D=0&genres%5BMystery%5D=0&genres%5BOne+Shot%5D=0&genres%5BPsychological%5D=0&genres%5BRomance%5D=0&genres%5BSchool+Life%5D=0&genres%5BSci-fi%5D=0&genres%5BSeinen%5D=0&genres%5BShoujo%5D=0&genres%5BShoujo+Ai%5D=0&genres%5BShounen%5D=0&genres%5BShounen+Ai%5D=0&genres%5BSlice+of+Life%5D=0&genres%5BSmut%5D=0&genres%5BSports%5D=0&genres%5BSupernatural%5D=0&genres%5BTragedy%5D=0&genres%5BWebtoons%5D=0&genres%5BYaoi%5D=0&genres%5BYuri%5D=0&released_method=eq&released=&rating_method=eq&rating=&is_completed=&advopts=1")
  if search_result.css('#listing tr:not(:first)').size > 0
    p "I found #{search_result.css('#listing tr:not(:first)').size} results"
    search_result.css('#listing tr:not(:first)').each_with_index do |result, index|
      p "#{index + 1}. #{result.css('td:first a').text}"
    end
    input = ask("Which one must I download ? (set number) :", Integer) { |i| i.in = 1..search_result.css('#listing tr:not(:first)').size }
    result = search_result.css('td:first a')[input - 1]
    download_manga result.text, result.attributes["href"].value.split('/').last
  else
    p "No result for for #{manga_name} :("
  end
end
class Manga
  attr_accessor :name, :chapters, :url
  def initialize name
    @chapters = []
    @name = name
    @url = "http://mangafox.me/manga/#{@name_slugified}"
    p " - #{@name} initialize"
  end

  def name_slugified
    slug = @name.gsub(" - ","_").gsub(/[\s+.!'"-:]/, "_").downcase
    slug = slug[0...-1] if slug[slug.size - 1] == "_"
    slug
  end
end

class Chapter
  attr_accessor :name, :pages, :url
  def initialize name, url
    @pages = []
    @name = name
    @url = url
    p " -- #{@name} initialize"
  end
end

class Page
  attr_accessor :url_image, :path_image
  def initialize url_image, path_image
    @url_image = url_image
    @path_image = path_image
    p " --- #{@url_image} initialize"
  end
end


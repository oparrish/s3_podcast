require 'rss/maker'
require 'optparse'
require 'uri'
require 'aws/s3'	

options={}

options[:language] = "en-us"

opts = OptionParser.new do |opts| 	
  opts.on("-t", "--title TITLE", "Title of podcast") do |title|
    options[:title] = title
  end
  
  opts.on("-l", "--link LINK", "Link of podcast") do |link|
    options[:link] = link
  end
  
  opts.on("-i", "--image IMAGE", "Image") do |image|
  	options[:image] = image
  end
  
  opts.on("-e", "--desc DESCRIPTION", "Description of podcast") do |desc|
  	options[:desc] = desc
  end
  
  opts.on("-n", "--lang [LANGUAGE]", "Language of feed") do |language|
    options[:language] = language
  end
  
  opts.on("-o", "--output OUTPUT", "Name of output file") do |output|
  	options[:output] = output
  end
  
  opts.on("-a", "--author [AUTHOR]", "Author of podcast items") do |author|
  	options[:author] = author
  end
  
  opts.on("-b", "--bucket [BUCKET]", "S3 bucket where enclosures are") do |bucket|
  	options[:bucket] = bucket
  end
  
  opts.on_tail("-h", "--help", "Show this message") do
    puts opts
    exit
  end
end

opts.parse!

version = "2.0"

AWS::S3::Base.establish_connection!(
  :access_key_id     => ENV['AMAZON_ACCESS_KEY_ID'],
	:secret_access_key => ENV['AMAZON_SECRET_ACCESS_KEY']
)

s3_bucket = AWS::S3::Bucket.find(options[:bucket])

content = RSS::Maker.make(version) do |m|
	m.channel.title = options[:title]
	m.channel.link = options[:link]
	m.channel.description = options[:desc]
	m.channel.language = options[:language]
	m.channel.itunes_image = options[:image]
	m.items.do_sort = true
	
	s3_bucket.select{|object| object.key =~ /[\s\w]+\.(m4b|mp3|m4a|ogg|aac)/}.each do |audio|
		i = m.items.new_item
		i.link = audio.url(:authenticated => false)  
		i.title = audio.key.split(".")[0]
		i.author = options[:author]
		i.pubDate = audio.last_modified
		i.guid.content = audio.etag
		i.enclosure.url = i.link
		i.enclosure.length = audio.content_length
		i.enclosure.type = audio.content_type
    i.description = audio.metadata[:description]
  end 
end

AWS::S3::S3Object.store(options[:output], content.to_s, options[:bucket], :access => :public_read, :content_type => "application/rss+xml")

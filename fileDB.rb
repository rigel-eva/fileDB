#!/usr/bin/env ruby
require "sqlite3"
require 'open-uri'
require 'rest_client'
require 'fileutils'
require 'tumblr_client'
OSXTAGS=(/darwin/ =~ RUBY_PLATFORM) != nil
#Getting keys, and tokens from a file to prevent this file from acciedentally displaying things it should not... if I chose to post it anywhere.
f=File.open("keys.json")
keys = JSON.parse(File.open("keys.json").read)
G_URL_SHORT_KEY=keys['gShort']
TUMBLR_KEY=keys['tKey']
TUMBLR_SECRET=keys['tSecret']
TUMBLR_O_TOKEN=keys['tOToken']
TUMBLR_O_SECRET=keys['tOSecret']
Tumblr.configure do |config|
	config.consumer_key = TUMBLR_KEY
	config.consumer_secret = TUMBLR_SECRET
	config.oauth_token = TUMBLR_O_TOKEN
	config.oauth_token_secret = TUMBLR_O_SECRET
end
def createDB(database_location="test.db")
	db = SQLite3::Database.new database_location
		puts "Executing createDB"
=begin
		Table files
		key:
			Provides the key for the database, so if we do add another table we can use this.
		location:
			Where the File is in the file system
				(Note, 255 seems excesive, but It could happen.)
		gID:
			The ID provided by google URL shortining
=end
	
	
=begin
	Table Tags
	gID: 
		the ID provided by google URL shortining
	Tag: 
		A tag provided by the original page
=end
	#Setting up the Tables
	db.execute("create table files(location varstring(255), gID varstring(8));")
	db.execute("create table tags(gID varstring(8),tag varstring(255))")
	db.execute("create view Double_Entries as Select *, COUNT(*) AS dupes from files GroupBy location Having (COUNT(*) > 1)")
	#Should add some code for tags, and tagging, but Let's not overcomplicate things.
	return database_location #Well, this way we can run this inside of the fileDB initilize object
end
class FileDB
	def initialize(database_location=createDB(), folderLocation="./")
		@db=SQLite3::Database.open database_location
		@fl=folderLocation
		@tc=Tumblr::Client.new(:client => :httpclient)
	end
	
	def FileDB.finalize(id)
		@db.close()
	end
	
	def addFile(fileLoc, webLoc)
		#This is a function that adds stuff to the Database based on the URL provided
		gShort=shortenURL(webLoc)
		gShort=gShort.body.split("\"")[7].split("/")[3]#this is to split it into only the part that we want. (There is probably a better way to do this ... )
		#@db.execute("select * from files;")
		@db.execute("insert into files (location, gID) VALUES (\"#{fileLoc}\",\"#{gShort}\");")
		return gShort
	end
	
	def findByFile(loc)
		@db.execute("select* from files where location=\"#{loc}\"")	
	end
	
	def addTumblrTags(fileLoc)
		gID=@db.execute("select * from files where location=\"#{fileLoc}\"")[0][1]
		loc=JSON.parse(lengthenURL("http://goo.gl/#{gID}"))['longUrl']
		tDomain=getTumblrDomain loc
		tPost=getTumblrPost loc
		tags=@tc.posts(tDomain, :id => tPost.to_i)['posts'][0]['tags']
		
			tags.each{|tag|
				#puts "SQL Executing: insert into tags (gID, tag) VALUES (\"#{gID}\",\"#{tag}\");"
				@db.execute("insert into tags (gID, tag) VALUES (\"#{gID}\",\"#{tag}\");")
				if(OSXTAGS)
					#puts "\tExecuting: tag -a \"#{tag}\" \"#{fileLoc}\""
					`tag -a \"#{tag}\" \"#{fileLoc}\"`
				end
			}
		#rescue Exception => e
			#puts "Weird ... there was an issue trying to get tags for: #{fileLoc}"
			
	end
	
	def getTumblr(loc)
		#We are trusting the user that this is a tumblr page ...
		if(loc.split("/")[2]=="goo.gl")
			loc=JSON.parse(lengthenURL(loc))['longUrl']
		end
		tDomain=getTumblrDomain loc
		tPost=getTumblrPost loc
		i=0
		download=Array.new
		get=@tc.posts(tDomain, :id => tPost.to_i)['posts'][0]['photos']
		get.each{|img|
			download[i]=img['original_size']['url']
			i+=1
		}
		fileLoc=""
		if(get.length>1)
			fileLoc="#{@fl}/Tumblr/#{tPost}/"
			
		else
			fileLoc="#{@fl}/Tumblr/"
		end
		FileUtils::mkdir_p fileLoc #covering our ass if the directory does not exist.
		download.each{|link|
			getFileFromURL(link,fileLoc)
			addFile(fileLoc+link.split('/')[-1], loc)
			addTumblrTags(fileLoc+link.split('/')[-1])
		}
	#rescue NoMethodError
		#puts "ERROR: It's likely that this particular link is not a link to a photo post: #{loc}"
	end
	
	protected
	
	def getFileFromURL(webLoc,folderLoc)
=begin
	Note: this utility will download into a directory based on where this file is located (aka if you wanted to downlaod something 	to the next directory up you would have to use "/../"
=end
		if(folderLoc[-1]!="/")
			folderLoc=folderLoc+"/"
		end
		open(folderLoc+webLoc.split("/")[-1], 'wb') do |file|
			file << open(webLoc).read
		end
	end 
	
	def shortenURL(webLoc)
		RestClient.post 'https://www.googleapis.com/urlshortener/v1/url?key='+G_URL_SHORT_KEY, {'longUrl' => webLoc, }.to_json, :content_type => :json, :accept => :json
	end
	
	def lengthenURL(gShort)
		RestClient.get "https://www.googleapis.com/urlshortener/v1/url?key=#{G_URL_SHORT_KEY}&shortUrl=#{gShort}",  :content_type => :json, :accept => :json
		
	end
	
	def getTumblrDomain(loc)
		tURL=loc.split("/")
		tDomain=tURL[2]
	end
	
	def getTumblrPost(loc)
		tURL=loc.split("/")
		tPost=tURL[-1]
		if(!(/^[\d]+(\.[\d]+){0,1}$/===tPost))#We are checking to see if we got the actual tumblr post id.
			tPost=tURL[-2]
		end
		return tPost
	end
end
if __FILE__==$0
	def test(line, db)
		return db.getTumblr(line)==false	
	rescue Errno::ECONNRESET => e
		puts "This post had an ssl error #{line} ... Should be nothing\n"
	rescue Exception => e
		puts "This post caused an error: #{line} This error to be precice:\n\n#{e.class}: #{e}\n"
		return true
	end
	if(!File.exists? "test.db")
		db=FileDB.new(createDB,"..")
	else
		db=FileDB.new("test.db","..")
	end
	f = File.open("./TumblrGet.txt", "r")
	f2= File.open("./TumblrGet.txt.tmp","w")
	i=0
	t=Array.new
	f.each_line do |line|
		#puts "#{i}: #{line}"
		t[i]=Thread.new{
			if(test(line,db)==false)
				f2.write(line)
			end
		}
		sleep 0.25
		i+=1
	end
	t.each{|thread| thread.join}
	FileUtils.mv "TumblrGet.txt.tmp", "TumblrGet.txt"
end
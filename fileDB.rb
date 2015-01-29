#!/usr/bin/env ruby
require "sqlite3"
require 'open-uri'
require 'rest_client'
require 'fileutils'
OSXTAGS=(/darwin/ =~ RUBY_PLATFORM) != nil
#Getting keys, and tokens from a file to prevent this file from acciedentally displaying things it should not... if I chose to post it anywhere.
KEYS = JSON.parse(File.open("keys.json").read)
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
	db.execute("create view double_entries as select*, COUNT(*) AS dupes from files Group By location Having(Count(*)>1)")
	db.execute("CREATE VIEW Double_Tags as Select *, COUNT(*) As dupes from tags Group By gID,tag Having(Count(*)>1)")
	#Should add some code for tags, and tagging, but Let's not overcomplicate things.
	return database_location #Well, this way we can run this inside of the fileDB initilize object
end
class FileDB
	CATCHLIMIT=10
	def initialize(database_location=createDB(), folderLocation="./")
		@db=SQLite3::Database.open database_location
		@fl=folderLocation
	end
	
	def FileDB.finalize(id)
		@db.close()
	end
	
	def addFile(fileLoc, webLoc)
		#This is a function that adds stuff to the Database based on the URL provided
		gShort=shortenURL(webLoc).split("/")[3]#this is to split it into only the part that we want. (There is probably a better way to do this ... )
		#@db.execute("select * from files;")
		@db.execute("insert into files (location, gID) VALUES (\"#{fileLoc}\",\"#{gShort}\");")
		return gShort
	end
	
	def findByFile(loc)
		@db.execute("select* from files where location=\"#{loc}\"")	
	end
	
	def addTags(tags, gID, fileLoc)
		tags.each{|tag|
			#puts "SQL Executing: insert into tags (gID, tag) VALUES (\"#{gID}\",\"#{tag}\");"
			@db.execute("insert into tags (gID, tag) VALUES (\"#{gID}\",\"#{tag}\");")
			if(OSXTAGS)
				#puts "\tExecuting: tag -a \"#{tag}\" \"#{fileLoc}\""
				`tag -a \"#{tag}\" \"#{fileLoc}\"`
			end
		}	
	end
	protected
	def removeDuplicateTags()
		db.execute("delete from tags where rowid not in(select min(rowid) from tags group by gID,tag)")
	end
	def removeDuplicateFiles()
		db.execute("delete from files where rowid not in(select min(rowid) from files group by location)")
	end
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
	
	def shortenURL(webLoc, catchRate=0)
		JSON.parse(RestClient.post('https://www.googleapis.com/urlshortener/v1/url?key='+KEYS['gShort'], {'longUrl' => webLoc, }.to_json, :content_type => :json, :accept => :json))['id']
	rescue RestClient::Forbidden
		if(catchRate<CATCHLIMIT)
			sleepTime=Random.rand(20)
			#puts "There was a 403 error when trying to shorten this URL: #{webLoc}, catchRate#{catchRate}, Sleep time:#{sleepTime}"
			sleep sleepTime
			shortenURL(webLoc,catchRate+1)
		else
			raise RestClient::Forbidden
		end
	end
	
	def lengthenURL(gShort)
		JSON.parse(RestClient.get("https://www.googleapis.com/urlshortener/v1/url?key=#{KEYS['gShort']}&shortUrl=#{gShort}",  :content_type => :json, :accept => :json))['longUrl']
		
	end
end

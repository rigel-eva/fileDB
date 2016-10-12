#!/usr/bin/env ruby
require 'sqlite3'
require 'open-uri'
require 'rest-client'
require 'fileutils'
require 'json'
OSXTAGS=(/darwin/ =~ RUBY_PLATFORM) != nil
#Getting keys, and tokens from a file to prevent this file from acciedentally displaying things it should not... if I chose to post it anywhere.
KEYS = JSON.parse(File.open("keys.json").read)
def createDB(database_location="test.db")
	db = SQLite3::Database.new database_location
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
	def self.finalize(id)
		proc {@db.close()}
	end
	def close()
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
	def addTags(tags, gID, fileLoc=nil)
		tags.each{|tag|
			@db.execute("insert into tags (gID, tag) VALUES (\"#{gID}\",\"#{tag}\");")
			if(!fileLoc.nil?&&OSXTAGS)
				`tag -a \"#{tag}\" \"#{fileLoc}\"`
			end
		}
	end
	def readTags(gID)
		#Returns all tags associated with the gID
		output=Array.new
		@db.execute("select Tag from tags where gID=\"#{gID}\"").each{|t|
			output.push(t[0])
		}
		return output
	end
	def getgIDsFromTags(tags)
		output=Array.new
		where=""
		tags.each{|tag|
			where+="tag=\""+tag+"\" or "
		}
		where.chomp!(" or ")#Removing that trailing or
		@db.execute("select gID from Tags where "+where).each{|gID|
			output.push(gID[0])
		}
		return output
	end
	def getLocation(gID)
		output=Array.new
		@db.execute("select location from files where gID=\"#{gID}\"").each{|loc|
			output.push(loc[0])
		}
	end
	def getgID(location)
		@db.execute("select gID from files where location=\"#{location}\"")[0][0] #Returns the first gID that we find in the database.
	end
	def addOSXTags(tags,fileLoc)
		if(OSXTAGS)
			tagList=""
			tags.each{|tag|
				tagList=tagList.concat "\"#{tag}\","
			}
			taglist[-1]=""#zeroing out the last comma to avoid confusing the tag command
			`tag -a #{tagList} \"#{fileLoc}\"`
			return true
		else
			return false
		end
	end
	def removeDuplicateTags()
		@db.execute("delete from tags where rowid not in(select min(rowid) from tags group by gID,tag)")
	end
	def removeDuplicateFiles()
		@db.execute("delete from files where rowid not in(select min(rowid) from files group by location)")
	end
	def shortenURL(webLoc, catchRate=0)
		JSON.parse(RestClient.post('https://www.googleapis.com/urlshortener/v1/url?key='+KEYS['gShort'], {'longUrl' => webLoc, }.to_json, :content_type => :json, :accept => :json))['id']
	rescue RestClient::Forbidden => e
		if(catchRate<CATCHLIMIT)
			sleepTime=Random.rand(20)
			puts "There was a 403 error when trying to shorten this URL: #{webLoc}, catchRate#{catchRate}, Sleep time:#{sleepTime}"
			sleep sleepTime
			shortenURL(webLoc,catchRate+1)
		else
			raise e
		end
	end
	def lengthenURL(gShort)
		JSON.parse(RestClient.get("https://www.googleapis.com/urlshortener/v1/url?key=#{KEYS['gShort']}&shortUrl=#{gShort}",  :content_type => :json, :accept => :json))['longUrl']
	end
	#protected
	def linkInDatabase?(webLoc)
		return !(@db.execute("select * from files where gID=\"#{shortenURL(webLoc).split("/")[-1]}\";")[0].nil?)
	end
	def fileInDatabase?(fileLoc)
		return !(@db.execute("select * from files where location=\"#{file}\"")[0].nil?)
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
end
if __FILE__==$PROGRAM_NAME
	require 'optparse'#Going to leave it up to whomever is writing the code if they want to have the user have the ability to change the options...
	def fileDBConverter(fileName)#Just to make some things a bit simpler in terms of the database.
		returner=fileName
		x=File.expand_path($0)
		x.slice!(__FILE__.split("/")[-1])
		x.slice!(x.split("/")[-1]+"/")
		unless(returner.slice!(x).nil?)
			returner="../"+returner
		end
		return returner
	end
	options = {}
	options[:db]="test.db"
	options[:fl]="./"
	#But, these should be taken as a guideline
	OptionParser.new do |opt|
		opt.on("--setDB Database_Location","Set the location of the database"){ |db| options[:db]=db}
		opt.on("--setFolder Folder_Location","Set the Folder Location of the Database (Usually ./)"){ |fl| options[:fl]=fl}
		opt.on("-f File_Location", "--file File_Location","The File that you are currently getting/setting information for"){ |file| options[:file]=file}
		opt.on("-t Tag1,Tag2,...,TagN", "--tags Tag1,Tag2,...,TagN","The Tag you are either setting or getting information on"){ |tag|
			options[:tag]=tag.split(',') }
		opt.on_tail("--getgID","Get the Google shortened url for the file") { options[:gID]=true}
		opt.on_tail("--ReadTags","Read the tags associated with the file"){options[:readTags]=true}
		opt.on_tail("--AddTags","Add a tag to the File"){options[:addTags]=true}
		opt.on_tail("--GetFilesFromTags","Get all files associated with any of the tags"){options[:getFilesFromTags]=true}
		opt.on("")
		#opt.on("-v", "--[no-]verbose", "Run verbosely"){|v| options[:v]=v}# Needed an example of a boolean switch...
	end.parse!
	db=FileDB.new(options[:db],options[:fl])
	if(!options[:readTags].nil?)
		puts db.readTags(db.getgID(fileDBConverter(options[:file])))
	elsif(!options[:getgID].nil?)
		puts db.getgID(fileDBConverter(options[:file]))
	elsif(!options[:addTags].nil?)
		puts db.addTags(options[:tag],db.getgID(fileDBConverter(options[:file])))
	elsif(!options[:getFilesFromTags].nil?)
		puts db.getgIDsFromTags(options[:tag]).each{|gID| db.getLocation(gID).each{|loc| puts loc}}
	end
	db.close
end

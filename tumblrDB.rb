load "fileDB.rb"
require 'tumblr_client'
require 'tempfile'
Tumblr.configure do |config|
	config.consumer_key = KEYS['tKey']
	config.consumer_secret = KEYS['tSecret']
	config.oauth_token = KEYS['tOToken']
	config.oauth_token_secret = KEYS['tOSecret']
end
class FileDB
	def initialize(database_location=createDB(), folderLocation="./")
		@db=SQLite3::Database.open database_location
		@fl=folderLocation
		@tc=Tumblr::Client.new(:client => :httpclient)
	end
	def addTumblrTags(fileLoc)
		gID=@db.execute("select * from files where location=\"#{fileLoc}\"")[0][1]
		loc=lengthenURL("http://goo.gl/#{gID}")
		tDomain=getTumblrDomain loc
		tPost=getTumblrPostID loc
		tags=@tc.posts(tDomain, :id => tPost.to_i)['posts'][0]['tags']
		addTags(tags, gID, fileLoc)
		#rescue Exception => e
			#puts "Weird ... there was an issue trying to get tags for: #{fileLoc}"
	end
	
	def getTumblrPost(loc)
		#We are trusting the user that this is a tumblr page ...
		if(loc.split("/")[2]=="goo.gl")
			loc=lengthenURL(loc)
		end
		tDomain=getTumblrDomain loc
		tPost=getTumblrPostID loc
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
		return true
	#rescue NoMethodError
		#puts "ERROR: It's likely that this particular link is not a link to a photo post: #{loc}"
	end
	
	def isTumlbr(fileLoc)
		
	end
	protected
	def getTumblrDomain(loc)
		tURL=loc.split("/")
		tDomain=tURL[2]
	end
	
	def getTumblrPostID(loc)
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
		return db.getTumblrPost(line)
	rescue Errno::ECONNRESET => e
		puts "This post had an ssl error #{line} ... Should be nothing\n\n"
		return false
	rescue Exception => e
		puts "This post caused an error: #{line} This error to be precice:\n\n#{e.class}: #{e}\n\n"
		return false
	end
	if(!File.exists? "test.db")
		db=FileDB.new(createDB,"..")
	else
		db=FileDB.new("test.db","..")
	end
	f = File.open("./TumblrGet.txt", "r")
	f2= Tempfile.new(["TumblrGet",".txt"])
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
	f2.flush
	FileUtils.cp f2.path, "./TumblrGet.txt"
	f2.close!
end
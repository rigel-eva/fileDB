#!/usr/bin/env ruby
load "fileDB.rb"
require 'nokogiri'
#API keys are needed ... however, due to deviantArt's Horrific API ... yeah ... nokogiri is tagging along for a reason
class FileDB
	def getDaPost(loc, ignoreInDatabase=false)
		if !ignoreInDatabase&&linkInDatabase?(loc) #If we are not ignoring the file is in the database, and the file is in the database
			return true #We are not going to even bother fetching it ...
		end
		if(loc[-1]=="/")
			loc[-1]=""
		end
		fileLoc="#{@fl}/deviantArt"
		rawhtml=Nokogiri::HTML(open(loc))
		getFileFromURL(rawhtml.xpath('//*[@property="og:image"]/@content').to_s, fileLoc)
		addFile(fileLoc+loc.split("/")[-1], loc)
		tags=Array.new()
		rawhtml.xpath('//*[@class="discoverytag"]/@data-canonical-tag').each{|tag|
			tags.push(tag.to_s)
		}
		addTags(tags,@db.execute("select * from files where location=\"#{fileLoc+loc.split("/")[-1]}\"")[0][1])
	end
end
if __FILE__==$0
	require 'tempfile'
	f = File.open("./daGet.txt", "r")
	f2= Tempfile.new(["daGet",".txt"])
	f3= File.open("./daFail.txt", "a+")
	i=0
	t=Array.new
	if(!File.exists? "test.db")
		db=FileDB.new(createDB,"..")
	else
		db=FileDB.new("test.db","..")
	end
	f.each_line do |line|
			t[i]=Thread.new{
				begin
					puts line
					if(!db.getDaPost(line))
						f2.write(line)
					end
				rescue
					f3.write(line)
					f3.write("\n")
				end
			}
			sleep 0.25
			i+=1
		
	end
	t.each{|thread| thread.join}
	f2.flush
	FileUtils.cp f2.path, "./daGet.txt"
	f2.close!
	f3.close
	db.close()
end
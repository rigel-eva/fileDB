#!/usr/bin/env ruby
load "fileDB.rb"
require 'tempfile'
#API keys are needed ... however, not here. due to the weird wibbily wobbly nature of Boorus
class FileDB
	def getDanPost(loc, retryCount=10, ignoreInDatabase=false)
		if !ignoreInDatabase&&linkInDatabase?(loc) #If we are not ignoring the file is in the database, and the file is in the database
			return true #We are not going to even bother fetching it ...
		end
		if(loc[-1]=="/")
			loc[-1]=""
		end
		fileLoc="#{@fl}/Booru/"
		link=danAPIHandler(loc)['file_url']
		#puts link
		if(link==""||link.nil?)
			link=danAPIHandler(loc)['representations']['full']
			#puts "Switching to Derpiboou"
			getFileFromURL("https:"+link,fileLoc)
		else
			getFileFromURL("https://"+getDanDomain(loc)+link,fileLoc)
		end
		FileUtils::mkdir_p fileLoc
		addFile(fileLoc+link.split("/")[-1], loc)
		getDanTags(fileLoc+link.split("/")[-1])
		return true
		rescue RestClient::TooManyConnectionsFromThisIP
			if(retryCount>0)
				puts "getDanPost: There are currently too many connections going on ... going to rest for a few, and go back online"
				sleep 1+10*Random.rand(10)
				return getDanPost(loc ,retryCount-1)
			else
				puts "getDanPost: Right, we are going to have to try this one later ..."
				return false
			end
		rescue NoMethodError
			puts "getDanPost: Right ... the Post at #{loc} probably got deleted ... crap"
			#rescue
			#	puts "Something has gone horribly wrong here ... : getDanPost(#{loc})"
			#	return false
	end
	def getDanPostFromID(id, retryCount=10)
		getDanPost("http://danbooru.donmai.us/posts/#{id}", retryCount)
		rescue RestClient::TooManyConnectionsFromThisIP
			if(retryCount>0)
				puts "getDanPostFromID: There are currently too many connections going on ... going to rest for a few, and go back online #{id}"
				sleep 3600+10*Random.rand(10)
				return getDanPostFromID(id ,retryCount-1)
			else
				puts"getDanPostFromID: Right, we are going to have to try this one later ... #{id}"
				return false
			end
	end
	def getDanPostsFromTag(tag, page=0, retryCount=10, posts={})
		t=Array.new
		i=0
		#currentPage=JSON.parse(RestClient.get("http://danbooru.donmai.us/posts.json?page=#{page}&tags=#{tag}&utf8=%E2%9C%93"))
		currentPage=Array.new
		loop do
			puts "On Page #{page} of Tag #{tag}"
			currentPage=danAPIHandler("http://danbooru.donmai.us/posts",{"page"=>"#{page}", "tags"=>tag, "utf8"=>"%E2%9C%93"})
			posts=[*posts, *currentPage]
			page+=1
			break if currentPage.nil? ||currentPage.empty?
		end
		if !posts.empty?
			posts.each do |x|
				if linkInDatabase?("http://danbooru.donmai.us/posts/#{x['id']}")#Is this link in our database?
					break #Oh it is? cool. we are done here folks.
				end
				t[i]=Thread.new{
					puts x['id']
					getDanPostFromID(x['id'])
				}
				sleep 0.25
				i+=1
			end
			t.each{|thread| thread.join}
		end
	rescue RestClient::TooManyConnectionsFromThisIP
			if(retryCount>0)
				puts "getDanPostsFromTag: There are currently too many connections going on ... going to rest for a few, and go back online #{tag}, #{page}"
				sleep 3600+10*Random.rand(10)
				return getDanPostsFromTag(tag, page ,retryCount-1, posts)
			else
				puts "getDanPostsFromTag: Right, we are going to have to try this one later ... #{tag}, #{page}"
				return false
			end
	end
	def getDanTags(fileLoc, retryCount=5)
		gID=@db.execute("select * from files where location=\"#{fileLoc}\"")[0][1]
		post=danAPIHandler(lengthenURL("http://goo.gl/#{gID}"))
		tags=Array.new()
		if(!(post['pool_string'].nil?))
			if(post['pool_string'].length>0)
				pool=post['pool_string'].split(" ")
				pool.collect!{|t|
					t=t.split(":")[1]
					}
				pool.each{|t|
					#My god that is a long command, but essentially it gets the pool name, and pushes it into the Tag array that we have set up.
					tag=danAPIHandler("http://danbooru.donmai.us/pools/#{t}")
					unless(tag.nil?)
						tags.push tag["name"]
					end
					}
			end
			tags.concat post['tag_string'].split(" ")
			tags.push("NSFW") if post["rating"]=="e"
			tags.push("Ecchi") if post["rating"]=="q"
			tags.push("SFW") if post["rating"]=="s"
			tags.collect!{|t|
				t=t.gsub("_"," ")
			}
		elsif(!(post['tags'].nil?))
			tags=post['tags'].split(", ")
		else
			raise "This is not a Booru Site ... please try again"
		end
		addTags(tags,gID, fileLoc)
	rescue RestClient::ResourceNotFound
		puts "getDanTags: Right ... 404 error ... assuming that "
	rescue RestClient::TooManyConnectionsFromThisIP
		if(retryCount>0)
			puts "getDanTags: right, we must have caused too many connections at the moment, we are going to rest, and retry"
			sleep 3600+10*Random.rand(10)
			getDanTags(fileLoc, retryCount-1)
		else
			puts "getDanTags: welp, giving up on that one... getDanTags(#{fileLoc})"
		end
	end
	#protected
	def getDanPostID(webLoc)
		webLoc.split("/")[-1]
	end
	def getDanDomain(webLoc)
		if(webLoc.split("/")[0].downcase!="http:"&& webLoc.split("/")[0].downcase!="https:")
			return webLoc.split("/")[0]
		else
			return webLoc.split("/")[2]
		end
	end
	def danAPIHandler(resource, options={})
		url="#{resource.gsub("\n",'')}.json?"
		if(!KEYS[getDanDomain(resource)].nil?)
			url+=url="login=#{KEYS[getDanDomain(resource)]["login"]}&api_key=#{KEYS[getDanDomain(resource)]["api_key"]}&"
		end
		unless(options.empty?)
			options.each{|key, value|
				url+=url="#{key}=#{value}&"
			}
		end
		#puts url
		return JSON.parse(RestClient.get(URI::encode(url),:content_type => :json, :accept => :json))
		rescue RestClient::ResourceNotFound
			puts "404, Could not find #{resource}"
		rescue RestClient::Gone
			puts "401, could not find #{resource}"
	end
end
if __FILE__==$0
	def test(db, line)
		return db.getDanPost(line)
	rescue URI::InvalidURIError
		puts "This Line is not a valid URI: #{line}"
		sleep 1+10*Random.rand(10)
		return false
	rescue RestClient::TooManyConnectionsFromThisIP
		puts "There are currently too many connections going on ... going to rest for a few, and go back online"
		sleep 1+10*Random.rand(10)
		return false
	rescue RestClient::Forbidden
		puts"We got a 403 Error from this URI: #{line}"
		sleep 1+10*Random.rand(10)
		return false
	end
	if(!File.exists? "test.db")
		db=FileDB.new(createDB,"..")
	else
		db=FileDB.new("test.db","..")
	end
	f = File.open("./DanGet.txt", "r")
	f2= Tempfile.new(["DanGet",".txt"])
	f3= File.open("./danTags.txt", "r")
	i=0
	t=Array.new
	f.each_line do |line|
		#puts "#{i}: #{line}"
		t[i]=Thread.new{
			if(db.getDanPost(line)==false)
				f2.write(line)
			end
		}
		sleep 0.25
		i+=1
	end
	t.each{|thread| thread.join}
	f2.flush
	FileUtils.cp f2.path, "./DanGet.txt"
	f2.close!
	t=Array.new
	f3.each_line do |line|
		#t[i]=Thread.new{
			puts line.tr(" \n\t", '')
			db.getDanPostsFromTag(line.tr(" \n\t", ''))
		#}
	end
	t.each{|thread| thread.join}
end

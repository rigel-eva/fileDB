#!/usr/bin/env ruby
load "danbooruDB.rb"                        #Load our lovely database handler
def getGoogleID(location, dbl)
  return dbl.getgID("../Booru/#{location}")
rescue NoMethodError
end
db=FileDB.new("test.db","..")
zeroSize=Array.new()                        #Generate an empty array for our zero filesize to go
Dir.entries('../Booru/.').each{|file|       #For all Files in the directory
  if(File.stat("../Booru/#{file}").size==0) #If A file has No size
    zeroSize<<file                          #Add it to our array
  end
}
zeroSize.each{|file|
  gID=getGoogleID(file, db)
  if(gID.nil?)              #If the database has no idea what the hell we are talking about
    next                    #we continue on ... for now ...
  end
  db.getDanPost(db.lengthenURL("http://goo.gl/#{gID}"),10,true)#Otherwise retry getting the god damn file!
}

#!/usr/bin/env ruby
load 'danbooruDB.rb'
db= FileDB.new("test.db","..")
SQLite3::Database.open("./test.db").execute("select location from files where location like \"%Booru%\"").each{|file|
	db.getDanTags("#{file[0]}")
}
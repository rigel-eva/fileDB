# **FileDB - A silly danbooru/tumblr downloader**

## Intro:
I made this thing a while back and don't really keep it all that well updated, so I wouldn't really expect to much. This was  my experimentation with a few APIs, and interacting with them.

## Setup:
To begin you want to go ahead and download the gems specified in the gem file.

You are also going to have to specify keys in a file called `keys.json` using a format similar to `keys-example.json`. You don't need all of the keys specified in the example, but you are going to need the ones relate to which service you want to use. The only key that is absolutely needed is one for Google Cloud Compute (for access to their url shortener)

If you want to play around with tumblr you are gonna want to specify some posts with images that you'd like to have downloaded in a file called `TumblrGet.txt` (one post per line!). There is currently no tag support for tumblr (probably should implement that at some point) and to initiate a fetch run `ruby tumblrDB.rb` whenever you want to fetch images from tumblr

And if you want to mess around with Danbooru, you can either specify tags in a file called `danTags.txt` or a particular image in `DanGet.txt` Then run `ruby danbooruDB.rb` whenever you want to fetch images from Danbooru or scan tags

## Generated database:
The SQLite database generated from both of these is set up with a few quirks that should be explained. The database stores both a link to the original download (gID key in both the files and the tags tables) where the file is currently on disk (location in files table) and any tags that were on the image at the time of the download (tag in tags table).

## Final Note:
I'm not sure what you're gonna use this for, but if it was for my original use (gathering reference images to learn to draw) Good Luck, and Have Fun!

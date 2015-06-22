#Ruby-fetch#
```
ruby fetch images using parallel. supports mzitu/doubanfuli/twitter/blogspot
this is a testing file for ruby parallel i/o processing.
```
#### notice: accessing blogspot/twitter from proxy goagent.

### usage:
```shell
    ./mz.rb mzt ./mzt							# fetch mzitu/share images
	./mz.rb dbf ./dbf							# fetch doubanfuli.com images save to ./dbf/ directory
	./mz.rb arc t1constantine ./raw_urls.txt	# fetch blogspot user t1constantine archives and save url to ./raw_urls.txt
	./mz.rb flt ./raw_urls.txt ./pass_urls.txt	# filter urls 
	./mz.rb url ./pass_urls.txt ./blogspot/		# load urls from pass_urls.txt and fetch images save to ./blogspot/
	./mz.rb twt T1_constantine ./twt			# fetch twitter user images and save to twt
```
BSD license. Enjoy.
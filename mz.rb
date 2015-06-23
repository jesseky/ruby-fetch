#!/usr/bin/env ruby
=begin
# author: jesse 
# mail  : microji@126.com 
# time  : 2015-06-22
# ruby fetch images using parallel. supports mzitu/doubanfuli/twitter/blogspot
# this is a testing file for ruby parallel i/o processing.
# notice: accessing blogspot/twitter through goagent proxy.
# usage: 
#	./mz.rb mzt ./mzt							# fetch mzitu/share images
#	./mz.rb dbf ./dbf							# fetch doubanfuli.com images save to ./dbf/ directory
#	./mz.rb arc t1constantine ./raw_urls.txt	# fetch blogspot user t1constantine archives and save url to ./raw_urls.txt
#	./mz.rb flt ./raw_urls.txt ./pass_urls.txt	# filter urls 
#	./mz.rb url ./pass_urls.txt ./blogspot/		# load urls from pass_urls.txt and fetch images save to ./blogspot/
#	./mz.rb twt T1_constantine ./twt			# fetch twitter user images and save to twt
# BSD license.
=end

require 'nokogiri'
require 'open-uri'
require 'open_uri_redirections'
require 'yaml'
require 'json'
require 'parallel'
# require 'thread' # no need now

class Hash
  def symbolize_keys!
    keys.each do |key|
      self[(key.to_sym rescue key) || key] = delete(key)
    end
    self
  end
end

class FetchLite
	
	def initialize(opt={})
		trap("INT") do 
			puts " Interrupt, Exit." 
			exit 130
		end
		ENV['http_proxy'] = ENV['https_proxy'] = "http://127.0.0.1:8087" if opt[:proxy]
		@agent = opt['agent'] || 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10.10; rv:38.0) Gecko/20100101 Firefox/38.0'
	end
	
	def fetch_page_image(url, opt)
		opn = {'User-Agent'=>@agent, :allow_redirections=>:safe}
		begin
			num = opt[:end] || open(url, opn).read.scan(opt[:fn_page]).flatten[0].to_i
		rescue => e
			abort "url: #{url}, error: #{e.message}"
		end
		str = opt[:str] || 1
		nxt = "" if opt[:next_page]
		puts "start from: #{str} to: #{num}"
		str.upto(num) do |p|
			u = url.is_a?(Array) ? url[p-1] : url+(nxt ? (nxt.empty? ? '' : opt[:page_url] % nxt) : opt[:page_url] % p)
			begin 
				htm = open(u, opn).read
				doc = Nokogiri::HTML.parse(opt[:json_key] ? JSON.parse(htm)[opt[:json_key]] : htm) 
			rescue => e
				puts "url: #{u}, error: #{e.message}" 
				break
			end
			start,found,fnum,imgs = Time.now,0,0,doc.css(opt[:img_query])
			Parallel.each_with_index(imgs, :in_threads=>opt[:threads] || 10) do |m,i|
				img = m.attr(opt[:attr] || 'src')
				img = img.scan(opt[:fn_img]).flatten[0] if opt[:fn_img]
				file = opt[:fn_name] ? opt[:save_path] % File.basename(img).sub(opt[:fn_name],'') : opt[:save_path] % [p,imgs.size,i+1,File.extname(img)]
				found += 1 if File.exists?(file)
				begin
					fnum += 1 if !File.exists?(file) && IO.write(file,open(img, opn).read) > 0 
				rescue => e
					puts "img: #{img} , #{e.message}"
				end
			end
			puts "page: %03d, img: %03d, fetch: %03d, time: %.2fs" % [p,imgs.size,fnum,(Time.now-start).to_f]
			nxt = htm.scan(opt[:next_page]).flatten[opt[:next_index]] if nxt
			break if opt[:next_page] && (!nxt || found > 0 && !opt[:force_go])
		end
	end

	def load_urls_from_file(file, opt={})
		abort "File #{file} not exists." unless file.is_a?(Array) || File.exists?(file) 
		(file.is_a?(Array) ? file : IO.read(file).chomp.split("\n")).select{|l| l && l.size>0}.map{|l| opt[:keep] ? l : l.split("\t")[0]}
	end
	
	def fetch_urls_image(file, opt)
		urls = load_urls_from_file file
		opt[:end] = urls.size unless opt[:end] && opt[:end].is_a?(Fixnum) && opt[:end] <= urls.size
		fetch_page_image urls, opt
	end 

	def archive(url, opt)
		opn = {'User-Agent'=>@agent, :allow_redirections=>:safe}
		begin
			result, start, mon = [], Time.now, Nokogiri::HTML.parse(open(url, opn)).css(opt[:month_query])
		rescue => e
			abort "url: #{url}, error: #{e.message}"
		end
		Parallel.each(mon, :in_threads=>[opt[:threads] || 10, mon.size].min) do |m|
			begin 
				istart, u = Time.now, m.attr('href') 
				v = open(opt[:list_url] % URI.encode(u, /\W/), opn).read
				v = v.scan(opt[:result_reg])[0][0] if opt[:result_reg] && v
				b = YAML.load(v)[opt[:result_key]] if v
				s = b.map{|l| opt[:save_fmt] % l.symbolize_keys!} if b
				result = result.concat s if s
				puts "num: %03d [%.2f] %s" % [s.size, Time.now-istart, u] if s
			rescue => e
				puts "url: #{u}, #{e.message}"
			end
		end
		puts "total: %d, time: %.2fs" % [result.size, Time.now-start]
		IO.write(opt[:save_file], result.sort.join("\n"))
	end

	def filter_urls(f_file, t_file, opt={})
		worked, ret, rfn, sug, exl,url = 0,[],opt[:url_refine],opt[:sug_match],opt[:exclude],load_urls_from_file(f_file,:keep=>true)
		url.each_slice(10) do |bat| # 10 个一批次
			ds, sk = [], []
			worked += bat.size
			bat.each_with_index do |l,i| 
				va = l.split("\t", 2)	
				va[0] = va[0].scan(rfn)[0] if rfn
				sg = sug && l =~ sug && !(exl && exl.any?{|e| l.include? e }) ? '-' : ' ' # sug 表示正则匹配建议选择的项目
				sk << i if '-' == sg
				ds << "[%d] %s %s\n" % [i, sg, va.join("\t")] # ds 表示 display，显示出时忽略url 
			end
			key = 
			if opt[:auto] then sk
			else
				puts ds.join+"输入保留编号: Y 全部保留，- 使用建议，回车忽略，区间：0 2 58 = [0 2 5 6 7 8]"
				kep = STDIN.gets.chomp.upcase # 交互获取输入
				case kep
				when 'Y' then (0..bat.size-1).to_a  	
				when '-' then sk
				else kep.split(/[\s+]/).map{|i| i.size>1 ? Range.new(*i.split('', 2).map(&:to_i)).to_a : i.to_i}.flatten.sort.uniq
				end unless kep.empty? || kep == 'N'
			end
			puts "[%02d%%] Select: #{key}" % (100*worked / url.size) 
			ret = ret.concat(bat.values_at(*key).compact) if key && key.size > 0
		end	
		puts "Filter: %d" % ret.size
		IO.write(t_file, ret.join("\n"))
	end
end

wch = ARGV[0] if ARGV[0] 
abort "must set argv which" unless wch
opt = {} 
argvs_str = ARGV.grep(/^str=[1-9][0-9]*$/)[0]
argvs_end = ARGV.grep(/^end=[1-9][0-9]*$/)[0]
opt[:str] = argvs_str[4..-1].to_i if argvs_str
opt[:end] = argvs_end[4..-1].to_i if argvs_end

case wch 
when "mzt"
	url = "http://www.mzitu.com/share/"
	abort "need save dir argument" unless ARGV[1] && Dir.exists?(ARGV[1])	
	opt.merge!({:fn_page=>%r|<span class='page-numbers current'>(\d+)</span>|, :page_url=>"comment-page-%d", :threads=>20,
	   :img_query=>".commentlist img", :save_path=>"./#{ARGV[1].chomp('/')}/%03d-%02d-%02d%s"})
	FetchLite.new.fetch_page_image url, opt
when "dbf"
	url = "http://www.doubanfuli.com/"
	abort "need save dir argument" unless ARGV[1] && Dir.exists?(ARGV[1])	
	opt.merge!({:fn_page=>%r|<a href='.*/(\d+)'>最后</a>|, :page_url=>"page/%d", :threads=>20,
	   :img_query=>"article img[src*=timthumb]", :fn_img=>/src=([^&]+)/, :save_path=>"./#{ARGV[1].chomp('/')}/%03d-%02d-%02d%s"})
	FetchLite.new.fetch_page_image url, opt
when "url"
	abort "need file argument" unless ARGV[1] 
	abort "need save dir argument" unless ARGV[2] && Dir.exists?(ARGV[2])
	opt.merge!({:threads=>20, :img_query=>".post-body img[src^=http]", :save_path=>"#{ARGV[2].chomp('/')}/%02d-%03d-%03d%s"})
	FetchLite.new(:proxy=>true).fetch_urls_image ARGV[1], opt
when "twt"
	abort "need user argument" unless ARGV[1]
	abort "need save dir argument" unless ARGV[2] && Dir.exists?(ARGV[2])
	url = "https://twitter.com/i/profiles/show/#{ARGV[1]}/media_timeline?include_available_features=1&include_entities=1&last_note_ts=1943"
	opt.merge!({:img_query=>".media-thumbnail", :attr=>'data-url', :end=>Float::INFINITY, 
				:next_page=>/stream-item-tweet-(\d+)/, :next_index=>-1, :page_url=>'&max_position=%s', :json_key=>'items_html',
				:save_path=>"#{ARGV[2].chomp('/')}/%s", :fn_name=>/:\w+$/, :force_go=>true})
	FetchLite.new(:proxy=>true).fetch_page_image url, opt 
when "arc"
	abort "need site argument" unless ARGV[1] 
	abort "need save file argument" unless ARGV[2] 
	url = "http://#{ARGV[1]}.blogspot.com/"
	opt.merge!({:month_query=>'#BlogArchive1_ArchiveList a.post-count-link[href*=archive]', 
				:list_url=>"#{url}?action=getTitles&widgetId=BlogArchive1&widgetType=BlogArchive&responseType=js&path=%s",
				:result_reg=> /'getTitles',(.*)\);\n\} catch/, :result_key=>"posts", :threads=>10, 
				:save_fmt=>"%{url}\t%{title}", :save_file=>ARGV[2] })
	FetchLite.new(:proxy=>true).archive url, opt	
when "flt"
	abort "need from file param" unless ARGV[1]
	abort "need to file param" unless ARGV[2]
	opt = {:url_refine=>/\d{4}\/\d{2}/, :sug_match=>/^(?!.*MKV).*\[\d+P\].*$/i, 
		   :exclude=>%w(13/10/15p.html 13/10/9p-36p.html heros12p 13/11/b29p.html motorbike 15/04/28p.html 15/04/29p.html 15/04/31p.html), 
		   :auto => ARGV[3] == '-' ? true : false }
	FetchLite.new.filter_urls ARGV[1], ARGV[2], opt
else
	puts "nothing to do"
end 



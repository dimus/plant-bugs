#!/usr/bin/env ruby
require "csv"

puts "\n" * 5
term = ARGV.join(" ")
table = nil
headers = nil
count = 0
open("all_tables.csv").each do |l|
  if l && l[0..1] == "t:"
    table = l.gsub(/,.*/, "")
    count = 1
  elsif count == 1
    headers = CSV.parse(l).first.select { |h| h && h.strip != "" }
    count = 0
  end
  if l.match /#{term}/
    puts "*" * 80
    puts table
    data = headers.zip(CSV.parse(l).first[0..headers.size])
    data.each do |k, v|
      puts "%s: %s" % [k,v]
    end
  end
end

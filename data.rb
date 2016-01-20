#!/usr/bin/env ruby
require "mysql2"

class Bugs
  def initialize
    @db = Mysql2::Client.new(host: :localhost, username: :root, database: :bugs)
  end

  def collect_names
    q1 = "select g.name as genus, sg.name as subgenus, t.name, t.avail_epithet, orig_genus_id, genus_id, rank, fossil from taxon t join taxon_genus g on g.id = t.genus_id join taxon_subgenus sg on sg.id = t.subgenus_id"
    @db.query(q1).each_with_object([]) do |n, ary|
      require "byebug"; byebug
      puts ""
    end
  end
end

b = Bugs.new

names = b.collect_names

puts names

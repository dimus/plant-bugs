#!/usr/bin/env ruby

require "mysql2"
require "csv"

class Db

  def initialize
    @db = Mysql2::Client.new(host: :localhost, username: :root, database: :bugs)
    @file = "all_tables.csv"
    @table = nil
    @headers = nil
    @count = 0
  end

  def make_table(row)
    cols = []
    q2 = []
    @db.query("drop table if exists #{@table}")
    @headers.each_with_index do |h, i|
      type = row[i].to_i.to_s == row[i] ? "int(11)" : "varchar(255)"
      q = "`#{h}` #{type}"
      if h == "id"
        q += " primary key"
      end
      cols <<  q
      if h[-3..-1] == "_id"
        q2 << "create index `idx_#{h}` on `#{@table}` (#{h})"
      end
    end
    q = "create table `#{@table}` (#{cols.join(",")})"
    puts q
    @db.query(q)
    q2.each { |q| @db.query(q) }
  end

  def add_row(row)
    return unless row
    row = row[0...@headers.size]
    val = row.map do |v|
      if v.to_i.to_s == v || v == "NULL"
        v
      else
        "'%s'" % @db.escape(v) rescue "NULL"
      end
    end
    q = "insert into %s values (%s)" % [@table, val.join(",")]
    @db.query(q)
  end

  def process_data
    CSV.open(@file).each do |r|
      col1 = r[0] ? r[0].strip : nil
      next unless col1
      if col1[0..1] == "t:"
        @table = col1[2..-1]
        @count = 0
        next
      end
      @count += 1
      puts "adding row %s to table %s" % [@count, @table] if @count % 1000 == 0
      case @count
      when 1
        @headers = r.select { |c| c && c.strip != "" }
      when 2
        make_table(r)
        add_row(r)
      else
        add_row(r)
      end
    end
  end
end

Db.new.process_data

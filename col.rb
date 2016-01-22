#!/usr/bin/env ruby

require "mysql2"
require "ostruct"
require "json"

class Db
  def self.query(query)
    unless defined? @@db
      @@db = Mysql2::Client.new(host: :localhost,
                               username: :root, database: :bugs)
    end
    @@db.query(query)
  end
end

class Taxon < OpenStruct
  def reference(id, original = false)
    return self.references[id] if self.references[id]
    res = Db.query("select
                       d.name as distribution, rc.description as comment,
                       b.title, b.year, b.pub_year, p.name as details,
                       a.long_name, a.short_name
                     from reference r
                       join biblio_instance bi on bi.id = r.biblio_instance_id
                       join distribution d on r.distribution_id = d.id
                       join ref_comment rc on rc.reference_id = r.id
                       join bibliography b on b.id = bi.bibliography_id
                       join publication p on p.id = b.publication_id
                       join authority a on a.Weeks=bi.primary_authority_id
                     where r.id = #{id}").first
   self.references[id] = Reference.new(res.merge(original: original)) if res
  end

  def populate_refs
    reference(orig_ref_id, true)
    res = Db.query("select id from reference where taxon_id = #{id}")
    res.each do |r|
      reference(r["id"], r["id"] == orig_ref_id) unless references[r["id"]]
    end
  end

  def authorship
    ref = self.references[self.orig_ref_id]
    authorship = ref ? normalize_authorship(ref.short_name) : nil
    year = ref ? ref.year : nil
    authorship = "%s, %s" % [authorship, year] if authorship && year
    self.genus_id != self.orig_genus_id ? "(#{authorship})" : authorship
  end

  def sci_name
    [self.fix_subgenus, self.authorship].join(" ")
  end

  def fix_subgenus
    parts = name.split(/\s+/)
    parts[1] = "(#{parts[1]})" if parts[1] && parts[1].match(/^[A-Z]/)
    parts.join(" ")
  end

  def populate
    populate_refs
    @obj = { id: id, parend_id: parent_taxon_id,
              name: sci_name, canonical: fix_subgenus,
              subgenus: subgenus == "undefined" ? nil : subgenus,
              authorship: authorship,
              refs: []}
    references.each do |k, v|
      @obj[:refs] << { id: k, orig: v.original,  author: v.long_name,
                       year: (v.pub_year || v.year), title: v.title,
                       details: v.details,
                       distribution: v.distribution, comment: v.comment}
    end
    self
  end

  def obj
    @obj
  end

  private
  def normalize_authorship(authorship)
    return authorship unless authorship
    authorship.gsub(/^(.*), ([A-Z]\.)(.*)$/, '\2 \1\3')
  end
end

class Reference < OpenStruct
  def reformat_authors
  #   first_author = /^(([^,]+),(\s*[A-Z]\.*?)+(,\s*Jr\.)?)(,|and|$)/
  #   puts long_name
  #   match = long_name.match(first_author)
  #   au = match ? match[1] : "???"
  #   puts au
  end
end

class Col
  def initialize
    @taxon = nil
    @references = {}
    @authorship = nil
    @col = []
  end

  def valid_taxa
    Db.query("select t.*, ts.name as subgenus
              from taxon t
                join taxon_subgenus ts on ts.id = t.subgenus_id
              where availability='valid' and rank = 'species'")
              # and t.id in (11428, 146, 14617, 10154, 16342)")
  end

  def traverse_taxa
    res = []
    valid_taxa.each_with_index do |t, i|
      puts "Going through %s taxon" % i if i % 100 == 0

      taxon = Taxon.new(t.merge(references: {})).populate.obj
      taxon[:syns] = collect_synonyms(taxon[:id])
      res << taxon
    end
    w = open("t.json", "w:utf-8")
    w.write res.to_json
    w.close
  end

  def collect_synonyms(taxon_id)
    res = []
    synonyms = Db.query("select *
                           from taxon
                           where id in (
                             select junior_taxon_id
                               from synonym
                               where senior_taxon_id = #{taxon_id}
                                 and junior_taxon_id != senior_taxon_id)")
    synonyms.each do |s|
      res << Taxon.new(s.merge(references: {})).populate.obj
    end
    res
  end
end

col = Col.new
col.traverse_taxa

#!/usr/bin/env ruby

require "mysql2"
require "ostruct"

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
                       b.title, b.year, b.pub_year, p.name,
                       a.long_name, a.short_name
                     from reference r
                       join biblio_instance bi on bi.id = r.biblio_instance_id
                       join distribution d on r.distribution_id = d.id
                       join ref_comment rc on rc.reference_id = r.id
                       join bibliography b on b.id = bi.bibliography_id
                       join publication p on p.id = b.publication_id
                       join authority a on a.Weeks=bi.primary_authority_id
                     where r.id = #{id}").first
   self.references[id] = OpenStruct.new(res.merge(original: original))
  end

  def authorship
    ref = self.references[self.orig_ref_id]
    authorship = "%{short_name}" % ref
    puts authorship
    # "(#{authorship})" if self.genus_id != self.orig_genus_id
    puts ""
  end

end

class Reference < OpenStruct

end

class Col
  def initialize
    @taxon = nil
    @references = {}
    @authorship = nil
    @col = []
  end

  def valid_taxa
    Db.query("select * from taxon where availability='valid'")
  end

  def traverse_taxa
    valid_taxa.each do |t|
      @taxon = Taxon.new(t.merge(references: {}))
      @taxon.reference(@taxon.orig_ref_id, true)
      @taxon.complete_name =
      require "byebug"; byebug
      puts ""
    end
  end

end


col = Col.new
col.traverse_taxa

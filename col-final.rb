#!/usr/bin/env ruby

require "json"
require "biodiversity"
require "csv"

class Formatter
  FILE = "t.json"
  URL = "http://research.amnh.org/pbi/catalog/references.php?id="
  FAMILY = "Miridae"
  TABLES = {
    accepted_species: %w(
      AcceptedTaxonID Kingdom Phylum Class Order Superfamily Family Genus
      SubGenusName SpeciesEpithet AuthorString GSDNameStatus Sp2000NameStatus
      IsExtinct HasPreHolocene HasModern LifeZone AdditionalData LTSSpecialist
      LTSDate SpeciesURL GSDTaxonGUID GSDNameGUID
    ),
    references: %w(ReferenceID Authors Year Title Details),
    name_references_links: %w(ID ReferenceType ReferenceID),
    distribution: %w(
      AcceptedTaxonID DistributionElemen StandardInUse DistributionStatus
    ),
    synonyms: %w(
      ID AcceptedTaxonID Genus SubGenusName SpeciesEpithet AuthorString
      InfraSpeciesEpithet InfraSpeciesMarker InfraSpeciesAuthorString
      GSDNameStatus Sp2000NameStatus GSDNameGUID
    )
  }

  def initialize
    @data = JSON.parse(File.read(FILE), symbolize_names: true)
    @parser = ScientificNameParser.new
    @tables = {}
    @distributions = []
    set_files
  end

  def set_files
    TABLES.keys.each do |k|
      @tables[k] = CSV.open(file(k), "w:utf-8")
      @tables[k] << TABLES[k]
    end
  end

  def format
    @data.each_with_index do |d, i|
      @distributions = []
      puts "Processing %s data" % i if i % 1000 == 0
      parsed = @parser.parse(d[:canonical])[:scientificName]
      append_accepted_species(d, parsed)
      append_references(d[:id], d[:refs], "TaxAccRef")
      append_synonyms(d[:id], d[:syns])
      append_distribution(d[:id])
      break if i > 100
    end
  end

  def append_synonyms(taxon_id, syns)
    syns.each do |s|
      parsed = @parser.parse(s[:name])[:scientificName]
      infrasp = parsed[:details][:infraspecies] rescue nil
      infrasp_rank = nil
      next if infrasp && infrasp.size > 1
      genus = parsed[:details].first[:genus][:string]
      subgenus = parsed[:details].first[:subgenus][:string] rescue nil
      species = parsed[:details].first[:species][:string]
      if infrasp
        infrasp_rank = infrasp[0][:rank]
        inrfrasp = infrasp[0][:string]
      end
      @tables[:synonyms] << [s[:id], taxon_id, genus, subgenus, species,
                            infrasp, infrasp_rank, s[:authorship],
                            nil, nil, nil]
      append_references(s[:id], s[:refs], "Synonym")
    end
  end

  def append_distribution(taxon_id)
    d = @distributions.uniq
    d.delete("undefined")
    d = d.compact.sort.join("; ")
    @tables[:distribution] << [taxon_id, d, nil, nil]
  end

  def append_references(taxon_id, refs, type)
    refs.each do |r|
      ref = [r[:id], r[:author], r[:year], r[:title], r[:details]]
      type = r[:orig] ? "Nomenclatural" : type
      @distributions << r[:distribution]
      @tables[:references] << ref
      @tables[:name_references_links] << [taxon_id, type, r[:id]]
    end
  end

  def append_accepted_species(data, parsed)
    as = [data[:id], nil, nil, nil, nil, nil, FAMILY,
          parsed[:details][0][:genus][:string], data[:subgenus],
          parsed[:details][0][:species][:string],
          data[:authorship], nil, nil, nil, nil, nil, nil,
          nil, nil, nil, "#{URL}#{data[:id]}", nil, nil]
    @tables[:accepted_species] << as
  end


  private
  def file(name)
    "csv/" + name.to_s.split("_").map(&:capitalize).join("") + ".csv"
  end
end


f = Formatter.new

f.format

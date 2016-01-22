#!/usr/bin/env ruby

require "json"
require "biodiversity"
require "csv"

class Formatter
  FILE = "t.json"
  FAMILY = "Miridae"
  TABLES = {
    accepted_species: %w(
      AcceptedTaxonID Family Genus SubGenusName SpeciesEpithet AuthorString
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
      puts "Processing %s data" % i if i % 1000 == 0
      parsed = @parser.parse(d[:canonical])[:scientificName]
      taxon = [d[:id], FAMILY, parsed[:details]]
      puts taxon
    end
  end

  private
  def file(name)
    name.to_s.split("_").map(&:capitalize).join("") + ".csv"
  end
end


f = Formatter.new

f.format

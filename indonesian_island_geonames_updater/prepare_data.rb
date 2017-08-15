require 'csv'
require 'mediawiki_api'
require 'awesome_print'
require 'irb'
require_relative 'wikidata_query'

client = MediawikiApi::Client.new "https://www.wikidata.org/w/api.php"
query = <<QUERY
SELECT DISTINCT ?item ?itemLabel ?geonamesId ?coordinate
WHERE {
  ?item wdt:P31/wdt:P279* wd:Q23442.
  ?item wdt:P17 wd:Q252 .
  ?item wdt:P625 ?coordinate.
  ?sitelink schema:about ?item .
  ?sitelink schema:inLanguage 'ceb'
  FILTER EXISTS {
    ?item wdt:P1566 ?geonamesId
  }
  SERVICE wikibase:label { bd:serviceParam wikibase:language "id,en". }
}
ORDER BY ?item
QUERY

p 'parsing geonames'
geonames = CSV.open(__dir__ + '/data/ID.txt', col_sep: "\t", quote_char: '$',
  headers: [
    'geonameid',
    'name',
    'asciiname',
    'alternatenames',
    'latitude',
    'longitude',
    'feature class',
    'feature code',
    'country code',
    'cc2',
    'admin1 code',
    'admin2 code',
    'admin3 code',
    'admin4 code',
    'population',
    'elevation',
    'dem',
    'timezone',
    'modification date'
  ]).map(&:to_h)
# Remove any entities in geonames dataset that is not an Island to speed up lookup process and save it as “geonames_islands.csv”
geonames = geonames.select do |geoname|
  geoname['feature code'] && geoname['feature code'].match?(/ISL/)
end
File.write(__dir__ + '/data/geonames_islands.json', JSON.pretty_generate(geonames))
p 'completed parsing geoname'

p 'retreive wikidata items'
wikidata = AnakPulau::WikidataQuery.new(query: query).results
File.write(__dir__ + '/data/indonesian_islands_from_sparql.json', JSON.pretty_generate(wikidata))

p 'completed retreive wikidata item'

p 'retreive wikidata entities'
entities = {}
wikidata.each_slice(50) do |slice|
  ids = slice.map { |entity| entity['item']['value'].split('/').last }.join('|')
  entities.merge! client.action(:wbgetentities, ids: ids) \
  .data['entities']
end
File.write(__dir__ + '/data/1_indonesian_island_entities.json', JSON.pretty_generate(entities))
binding.irb
p 'retrieved wikidata entities'

# entities = JSON.parse File.read(__dir__ + '/data/1_indonesian_island_entities.json')
# geonames = JSON.parse File.read(__dir__ + '/data/geonames_islands.json')
p 'filter island that doesnt have "Exact Match" coordinate_wikidata with geonames get the claims'
claims = []
entities.each do |id, entity|
  entity['claims']['P625'].each do |coordinate|
    coordinate_wikidata = coordinate['mainsnak']['datavalue']['value']
    is_found = geonames.find do |geoname|
      coordinate_wikidata['latitude'].to_s == geoname['latitude'].to_s &&
      coordinate_wikidata['longitude'].to_s == geoname['longitude'].to_s
    end
    if is_found
      if coordinate['references']
        is_found_ref = coordinate['references'].find do |ref|
          if ref.dig('snaks', 'P248')
            ref.dig('snaks', 'P248').find do |snak|
              snak.dig('datavalue', 'value', 'id') == 'Q830106'
            end
          end
        end
        if !is_found_ref
          claims << coordinate
          break
        end
      else
        claims << coordinate
        break
      end
    end
  end
end
p 'completed filtering'
binding.irb
# using wbsetreference entpoint
File.write(__dir__ + '/data/2_claims_with_geonames.json', JSON.pretty_generate(claims))

p 'update wikidata claims'
claims.map! do |claim|
  {
    claim['id'] => {
      "P248": [{
        "snaktype": "value",
        "property": "P248",
        "datavalue": {
          value: {
                    "entity-type": "item",
                    "numeric-id": 830106,
                    "id": "Q830106"
                 },
          "type": "wikibase-entityid"
        },
        "datatype": "wikibase-item"
      }]
    }
  }
end
File.write(__dir__ + '/data/3_claims_updated_references.json', JSON.pretty_generate(claims))
p 'finished update wikidata claims'

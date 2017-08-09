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
geonames = CSV.open(__dir__ + '/data/id.txt', col_sep: "\t", quote_char: '$',
  headers: [
    'RC',
    'UFI',
    'UNI',
    'LAT',
    'LONG',
    'DMS_LAT',
    'DMS_LONG',
    'MGRS',
    'JOG',
    'FC',
    'DSG',
    'PC',
    'CC1',
    'ADM1',
    'POP',
    'ELEV',
    'CC2',
    'NT',
    'LC',
    'SHORT_FORM',
    'GENERIC',
    'SORT_NAME_RO',
    'FULL_NAME_RO',
    'FULL_NAME_ND_RO',
    'SORT_NAME_RG',
    'FULL_NAME_RG',
    'FULL_NAME_ND_RG',
    'NOTE',
    'MODIFY_DATE',
    'DISPLAY',
    'NAME_RANK',
    'NAME_LINK',
    'TRANSL_CD',
    'NM_MODIFY_DATE',
    'F_EFCTV_DT',
    'F_TERM_DT'
  ]).map(&:to_h)
# Remove any entities in geonames dataset that is not an Island to speed up lookup process and save it as “geonames_islands.csv”
count = 0
geonames = geonames.select do |geoname|
  geoname['DSG'] && geoname['DSG'].match?(/ISL/)
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

p 'retrieved wikidata entities'

# entities = JSON.parse File.read(__dir__ + '/data/1_indonesian_island_entities.json')
# geonames = JSON.parse File.read(__dir__ + '/data/geonames_islands.json')
puts "Jumlah Pulau #{entities.count.to_s}"
p 'filter island that doesnt have "Exact Match" coordinate_wikidata with geonames get the claims'
claims = []
claims = entities.select{ |id, v| !v['claims']['P2326'] }
puts "Jumlah pulau yang matching dengan data #{claims.count.to_s}"

p 'completed filtering'
File.write(__dir__ + '/data/2_claims_with_geonames.json', JSON.pretty_generate(claims))
#
# p 'finished update wikidata claims'

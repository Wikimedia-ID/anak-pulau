require 'csv'
require 'awesome_print'
require 'mediawiki_api'
# require 'httplog'
require 'irb'
require 'haversine'
require_relative 'wikidata_query'

def coordinate_in_radius?(radius, latitude_a, longitude_a, latitude_b, longitude_b)
  return(latitude_a == latitude_b && longitude_a == longitude_b) if radius == 0
  distance = Haversine.distance(
    latitude_a.to_f,
    longitude_a.to_f,
    latitude_b.to_f,
    longitude_b.to_f
  ).to_km
  distance < radius
end

client = MediawikiApi::Client.new "https://www.wikidata.org/w/api.php"
# client.log_in("Yana agun", ENV["WIKIMEDIA_PASSWORD"])

query = <<QUERY
SELECT DISTINCT ?item ?itemLabel ?sitelink ?lang ?geonamesId
WHERE {
  ?item wdt:P31/wdt:P279* wd:Q23442.
  ?item wdt:P17 wd:Q252 .
  ?sitelink schema:about ?item .
  ?sitelink schema:inLanguage 'ceb' .
  ?item wdt:P1566 ?geonamesId
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

File.write(__dir__ + '/data/geonames.cache.json', JSON.pretty_generate(geonames))

# geonames = JSON.parse File.read(__dir__ + '/data/geonames.cache.json')

p 'completed parsing geoname'
wikidata = AnakPulau::WikidataQuery.new(query: query).results
File.write(__dir__ + '/data/wikidata.cache.json', JSON.pretty_generate(wikidata))

p "Initial wikidata (uniquely identified by lang and item) #{wikidata.count}"
# wikidata = JSON.parse File.read(__dir__ + '/data/wikidata.cache.json')

# Checked manually and confirmed that it has been removed in geonames
deleted_values = [
  '1641003',
  '1644745',
  '1889741',
  '1899628',
  '1951444' # => In Geonames, it is considered as part of Timor Leste
]

p 'mapping wikidata json'
wikidata = wikidata.group_by { |x| x['item']['value'] }.select do |x, v|
  # Select only the island that created by [ 'ceb', 'sv'] bots
  v.map { |y| y['lang']['value'] }.sort == [ 'ceb', 'sv' ] &&
  !deleted_values.include?(v.first['geonamesId']['value'])
end
p 'completed mapping wikidata json'
p "Total setelah di hapus duplikat dan di ambil hanya ceb, sv #{wikidata.count}"

p 'matching wikidata and geonames'
matching_pair = {}
wikidata.each do |key, wd|
  next if deleted_values.include?(wd.first['geonamesId']['value'])

  field_location = geonames.find_index do |geoname|
    geoname['geonameid'] == wd.first['geonamesId']['value']
  end

  if field_location
    matching_pair.merge! key.split('/').last => geonames[field_location]
    geonames.delete_at field_location 
  else
    `echo #{wd.first['geonamesId']['value']} >> not_found`
  end
end
matching_pairs = JSON.parse File.read(__dir__ + '/data/matching_pairs.cache.json')
p 'completed matching wikidata and geonames'

count = 0
matching_pairs.keys.each_slice(50) do |matching_pair|
# Dir["data/wikidata/*"].each do
  entities = client.action(:wbgetentities, ids: matching_pair.join('|')).data['entities']
  File.write(__dir__ + "/data/wikidata/#{count}_#{count += 50}.json", JSON.pretty_generate(entities))
  # entities = JSON.parse File.read(__dir__ + "/data/wikidata/#{count}_#{count += 50}.json")
  entities.each do |id, statements|
    target_claims = statements['claims']['P625']

    target_claims.each do |target_claim|
      coordinat          = target_claim['mainsnak']['datavalue']['value']
      coordinate_geoname = matching_pairs[id]
      # Only update references unless it is exact same and doesn't have reference url
      if coordinat['latitude'].to_s == coordinate_geoname['latitude'].to_s &&
         coordinat['longitude'].to_s && coordinate_geoname['longitude'].to_s &&
         !target_claim['references']
         #  client.action :wbsetclaim, claim: target_claim.merge(references: [{
         #    snaks: {
         #        "P1566": [{
         #          "snaktype": "value",
         #          "property": "P1566",
         #          "datavalue": {
         #              "value": coordinate_geoname['geonameid'],
         #              "type": "string"
         #          },
         #          "datatype": "external-id"
         #        }]
         #    }}]).to_json
      else
        log = "http://wikidata.org/wiki/#{id}  lat: #{coordinat['latitude']} #{coordinate_geoname['latitude']}; long: #{coordinat['longitude']} #{coordinate_geoname['longitude']}"
        `echo "#{log}" >> unmatched_coordinate`
      end

    end if target_claims
  end
end



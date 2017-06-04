require 'irb'
require 'json'
require 'csv'
require 'overpass_api_ruby'
require 'byebug'

# Parsing arguments
# ARGV[0] is the Administrative area we want to find the island location
location = ARGV[0]

OVERPASS = OverpassAPI::QL.new()

# Search island that have tags started with wiki (as for now, it could be
# wikipedia or wikidata) with type way or releation (way for coastlines and
# to area within Indonesia
# relation for a geogpraphic area that represent an Island). The search scopped
MAIN_QUERY = <<QUERY
( area[name="#{location}"]; )->.a;
way[place="island"][~"^wiki"~".+?$"](area.a);
(._;>>;);
out;
rel[place="island"][~"^wiki"~".+?$"](area.a);
(._;>>;);
out;
QUERY

result = OVERPASS.query(MAIN_QUERY)

File.write("results/#{location}_islands.json",result.to_json)

# To csv
CSV.open("results/#{location}_islands.csv", 'w',
  col_sep: ',',
  write_headers: true,
  headers: [
    'Osm Id',
    'OSM URL',
    'Wikipedia Id',
    'Wikipedia Language',
    'Wikipedia URL',
    'Wikidata ID',
    'Wikidata URL',
    'Name'
  ]) do |csv|
    result.to_json.map do |j|
      if j.dig('tags', 'wikidata') || j.dig('tags', 'wikipedia')
        wikipedia_language = if j['tags']['wikipedia']
                                j['tags']['wikipedia'].split(':')[0]
                             else
                               ""
                             end

        wikipedia_path     = if j['tags']['wikipedia']
                                j['tags']['wikipedia'].split(':')[1].gsub("\s", "_")
                             else
                                ""
                             end
        wikipedia_url      = if !j['tags']['wikipedia'].nil?
                              "http://#{wikipedia_language}.wikipedia.org/wiki/#{wikipedia_path}"
                             else
                               ""
                             end

        row = [
                j['id'],
                "http://openstreetmap.org/#{j['type']}/#{j['id']}",
                j['tags']['wikipedia'],
                wikipedia_language,
                wikipedia_path,
                j['tags']['wikidata'],
                "http://wikidata.org/#{j['tags']['wikidata']}",
                j['tags']['name']
              ]
        csv << row
      end
    end
end

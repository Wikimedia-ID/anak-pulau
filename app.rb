require 'irb'
require 'json'
require 'csv'
require 'optparse'
require 'overpass_api_ruby'
require 'byebug'
require 'active_support/core_ext/hash/indifferent_access'
require 'active_support/core_ext/string/inflections'
require 'pp'

OPENSTREETMAP_HOST = 'http://openstreetmap.org'.freeze;

OPTIONS = OpenStruct.new({ extract_geoshape: false, location: '' })

# Parsing arguments
# ARGV[0] is the Administrative area we want to find the island location
OptionParser.new do |opt|
  opt.banner = "Usage: ruby app.rb 'location_name' [options]"
  opt.on('--extract-geoshape', 'Extract Island Geoshape') do |v|
    p v
    OPTIONS.extract_geoshape = v
  end
  opt.on_tail("-h", "--help", "Show complete options (This message)") do
    puts opt
    exit
  end
end.parse!

OPTIONS.location = ARGV[0]

OVERPASS = OverpassAPI::QL.new()

# Search island that have tags started with wiki (as for now, it could be
# wikipedia or wikidata) with type way or releation (way for coastlines and
# to area within Indonesia
# relation for a geogpraphic area that represent an Island). The search scopped
MAIN_QUERY = <<QUERY
( area[name="#{OPTIONS.location}"]; )->.a;
way[place="island"][~"^wiki"~".+?$"](area.a);
(._;>>;);
out meta;
rel[place="island"][~"^wiki"~".+?$"](area.a);
(._;>>;);
out meta;
way[place="islet"](area.a);
(._;>>;);
out meta;
rel[place="islet"](area.a);
(._;>>;);
out meta;
QUERY

result = ActiveSupport::HashWithIndifferentAccess.new OVERPASS.query(MAIN_QUERY)

File.write("results/#{OPTIONS.location}_islands.json",result.to_json)

# To csv
CSV.open("results/#{OPTIONS.location.gsub(/\s/, '_')}_islands.csv", 'w',
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
    'Name',
    'Editor',
    'ChangeSet'
  ]) do |csv|
    result['elements'].map do |j|
      if j.dig('tags', 'wikidata') || j.dig('tags', 'wikipedia')
        # Row Creation
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
                "#{OPENSTREETMAP_HOST}/#{j['type']}/#{j['id']}",
                j['tags']['wikipedia'],
                wikipedia_language,
                wikipedia_path,
                j['tags']['wikidata'],
                "http://wikidata.org/wiki/#{j['tags']['wikidata']}",
                j['tags']['name'],
                "#{OPENSTREETMAP_HOST}/user/#{j['user']}",
                "#{OPENSTREETMAP_HOST}/changeset/#{j['changeset']}"
              ]
        csv << row
        if(j['type'] == 'relation')
          relation_directory = "results/#{OPTIONS.location.gsub(/\s/, '_')}_contributors/#{j['tags']['name'].gsub(/\s/, '_')}"
          FileUtils.mkdir_p(relation_directory)
          j['members'].each do |member|
            if member['type'] == 'way'
              coresponding_way = result['elements'].detect { |element| element['id'] == member['ref'] }
              CSV.open("#{relation_directory}/way_#{coresponding_way['id']}_by_#{coresponding_way['user']}.csv", 'w',
                write_headers: true,
                headers: [ 'node_url',
                           'contributor_url' ]) do |csv_way|
                coresponding_way['nodes'].each do |node_ref|
                  coresponding_node = result['elements'].detect { |element| element['id'] == node_ref }
                  csv_way << ["#{OPENSTREETMAP_HOST}/node/#{coresponding_node['id']}",
                              "#{OPENSTREETMAP_HOST}/user/#{coresponding_node['user']}"]
                end
              end
            end
          end
        end
        if(j['type'] == 'way')
          way_directory = "results/#{OPTIONS.location.gsub(/\s/, '_')}_contributors/way_#{j['tags']['name'].gsub(/\s/, '_')}"
          FileUtils.mkdir_p(way_directory)

          # Extracting GeoShape
          if OPTIONS.extract_geoshape
            geo_json = {
              type: 'Polygon',
              coordinates: [[]]
            }
          end
          CSV.open("#{way_directory}/way_#{j['id']}_by_#{j['user']}.csv", 'w',
            write_headers: true,
            headers: [ 'node_url',
                       'contributor_url' ]) do |csv_way|
            j['nodes'].each do |node_ref|
              coresponding_node = result['elements'].detect { |element| element['id'] == node_ref }
              csv_way << ["#{OPENSTREETMAP_HOST}/node/#{coresponding_node['id']}",
                          "#{OPENSTREETMAP_HOST}/user/#{coresponding_node['user']}"]
              if OPTIONS.extract_geoshape
                geo_json[:coordinates].first.push([coresponding_node['lon'], coresponding_node['lat']])
              end
            end
            if OPTIONS.extract_geoshape
              File.write("#{way_directory}/way_#{j['id']}_by_#{j['user']}.geojson", geo_json.to_json)
            end
          end
          if OPTIONS.extract_geoshape
            geo_json = nil
          end
        end
      end
    end
end

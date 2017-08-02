require 'json'
require 'mediawiki_api'

client = MediawikiApi::Client.new "https://www.wikidata.org/w/api.php"
client.log_in(ENV['wkusername'], ENV['wkpassword'])

claims = JSON.parse(File.read(__dir__ + '/data/3_claims_updated_references.json'))

claims.each do |id, data|
  client.action('wbsetreference', { id: id, data: data }.to_json )
end

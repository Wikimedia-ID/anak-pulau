require 'json'
require 'mediawiki_api'
require 'io/console'
require 'httplog'
require 'logger'

logger = Logger.new('logs/post_to_wikidata.log')

client = MediawikiApi::Client.new "https://www.wikidata.org/w/api.php"
client.log_in(ENV['wkusername'], ENV['wkpassword'])

claims = JSON.parse(File.read(__dir__ + '/data/3_claims_updated_references.json'))
i = 0
claims.each do |data|
  begin
    client.action('wbsetreference', statement: data.keys[0], snaks: data.values[0].to_json, bot: true )
    logger.info('Udated ' + data.keys[0] + ' with ' + data.values[0].to_json)
    STDIN.getch if [1, 5, 50, 6000].include?(i += 1)
  rescue
    logger.error('Udated ' + data.keys[0] + ' with ' + data.values[0].to_json)
  end
end

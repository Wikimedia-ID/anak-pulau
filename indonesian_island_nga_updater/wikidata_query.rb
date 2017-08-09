require 'cgi'
require 'open-uri'
require 'json'
class AnakPulau
  class WikidataQuery

    def initialize(query:, lazy: false)
      @query = CGI.escape(query)
      run if !lazy
    end

    def results
      return @results if @results
      run
    end

    private
      def run
        @results = JSON.parse(request.read)['results']['bindings']
      end

      def build_url
        'https://query.wikidata.org/bigdata/namespace/wdq/sparql?format=json&query=' + @query
      end

      def request
        open(build_url)
      end
  end
end
require 'foursquare'
require 'active_support/core_ext/object/blank'
require 'cgi'
require 'net/https'
require 'json'
require 'ruby-debug'
require 'uri'
require 'mongo'
require 'lib/score_lookup'

class VenuesController < ApplicationController
  EARTH_RADIUS = 6378 #in km
  US_LAT = 40.47

  before_filter :get_connections

  def index
  end

  def show
    if params[:lat].blank? || params[:lon].blank?
      render :json => {:errors => "Need to pass in a lat and a lon"} and return
    end
    result = ScoreLookup.lookup(params[:lat], params[:lon])
=begin
    fs = Foursquare::Venue.new("T4ZOBBXF3AK522ZJHAWZTGELNNFUSQF4BC4HA4XLWJEAVZWD")
    result = fs.search(:ll => "#{params[:lat]},#{params[:lon]}",:query => params[:q])["response"]
    venues = []
    result["groups"].each do |group|
      venues += group["items"] if group["name"] == "Nearby"
    end

    venues.sort! {|a, b| b["stats"]["checkinsCount"] <=> a["stats"]["checkinsCount"]}
    venues.collect! do |v|
      v if v["stats"]["checkinsCount"] > 10
    end.compact!

    venue_ids = venues.collect do |v|
      v["id"]
    end
    scores = fetch_scores(venue_ids)
    render :text => "score fetching failed", :status => 400 and return
    result = scores.zip(venues).collect do |tuple|
      {
        :venue_id => tuple[0]["venue_id"],
        :name => tuple[1]["name"],
        :lat => tuple[1]["location"]["lat"],
        :lon => tuple[1]["location"]["lng"],
        :category => tuple[1]["categories"][0]? "" : tuple[1]["categories"][0]["parents"],
        :scores => tuple[0]["scores"]
      }
    end
    result.each do |r|
      @places_coll.insert({:loc_idx => {:lat => r[:lat], :lon => r[:lon]}, :result => r})
    end
=end
    render :text => "#{params[:callback]}(#{result.to_json});", :status => 200
  end

  def load_points(nabe)
  end

  def get_connections
    uri = URI.parse(ENV['MONGOHQ_URL'])
    @db = Mongo::Connection.new(ENV['MONGHQ_URL'])["sentiment"]#from_uri(ENV['MONGOHQ_URL'])["sentiment"]
    @places_coll = @db["places"]
  end

  def create_points(top_right, bottom_left, edge_length)
    result = []
    d_lat = delta_lat(edge_length, (bottom_left[:lat].to_f + top_right[:lat].to_f) / 2)
    d_lon = delta_lon(edge_length)

    start_lat = top_right[:lat].to_f - (d_lat / 2)
    start_lon = top_right[:lon].to_f - (d_lon / 2)

    lats = Array.new((((bottom_left[:lat].to_f - start_lat) / d_lat).to_i + 1).abs) { |i| start_lat - i * d_lat }
    lons = Array.new((((top_right[:lon].to_f - start_lon) / d_lon).to_i + 1).abs) { |i| start_lon - i * d_lon }

    lats.product(lons).collect do |lat, lon| 
      #points<< {:lat => lat, :lon => lon}
      self.insert({:lat => lat, :lon => lon})
    end
  end

private


end

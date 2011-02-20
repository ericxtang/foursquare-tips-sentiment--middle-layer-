require 'foursquare'
require 'active_support/core_ext/object/blank'
require 'cgi'
require 'net/https'
require 'json'
require 'ruby-debug'
require 'uri'
require 'mongo'

class AdminController < ApplicationController
  EARTH_RADIUS = 6378 #in km
  US_LAT = 40.47
  before_filter :get_connections

  def index
    @mongo_collections = @db.collections.sort! {|a, b| a.name <=> b.name}
    @mongo_collections.delete_if {|c| ["system.indexes"].include?(c.name)} 
  end

  def load_nabes()
    @db["nabes"].insert({:name => "lower east side", :top_right =>{:lat => 40.71785916529029, :lon => -73.9873194694519}, :bottom_left => {:lat => 40.71561477332607, :lon => -73.99334907531738}})
    @db["nabes"].insert({:name => "soho", :top_right =>{:lat => 40.72483581359807, :lon => -73.99467945098877}, :bottom_left => {:lat => 40.72233145987863, :lon => -74.00347709655762}})
    redirect_to :controller => :admin, :action => :index
  end

  def populate_places()
    nabe = @db["nabes"].find({"name" => params[:nabe]}).entries[0]
    points = create_points(nabe["top_right"], nabe["bottom_left"], 0.1)
    fs = Foursquare::Venue.new("T4ZOBBXF3AK522ZJHAWZTGELNNFUSQF4BC4HA4XLWJEAVZWD")
    venues = []
    points.each do |p|
      result = fs.search(:ll => "#{p[:lat]},#{p[:lon]}")["response"]
      result["groups"].each do |group|
        venues += group["items"] if group["name"] == "Nearby"
      end
    end
    venues.each do |r|
      @places_coll.insert({:loc_idx => {:lat => r[:lat], :lon => r[:lon]}, :result => r})
    end
  end

  def delete_collection
    #flash[:error] = "Cannot delete a non-empty collection" and return if !params[:name].blank? && @db[params[:name]].count > 0 
    @db[params[:name]].drop if !params[:name].blank?
    redirect_to :controller => :admin, :action => :index
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

    points = []
    lats.product(lons).collect do |lat, lon| 
      points << {:lat => lat, :lon => lon}
      #self.insert({:lat => lat, :lon => lon})
    end
    points
  end

private 

  def delta_lat(km, avg_lat)
    km.to_f/us_circumference(avg_lat) * 360
  end

  def delta_lon(km)
    km.to_f/earth_circumference * 360
  end

  def us_circumference(lat)
    (2 * Math::PI * EARTH_RADIUS * Math.cos(lat || US_LAT)).abs.to_i
  end

  def earth_circumference
    (2 * Math::PI * EARTH_RADIUS).abs.to_i
  end
end

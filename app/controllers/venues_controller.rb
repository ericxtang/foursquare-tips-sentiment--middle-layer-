require 'foursquare'
require 'active_support/core_ext/object/blank'
require 'cgi'
require 'net/https'
require 'json'
require 'ruby-debug'

class VenuesController < ApplicationController
  def index
    fs = Foursquare::Venue.new("T4ZOBBXF3AK522ZJHAWZTGELNNFUSQF4BC4HA4XLWJEAVZWD")
    result = fs.search(:ll => "#{params[:lat]},#{params[:lon]}",:query => params[:q])["response"]
    venues = []
    result["groups"].each do |group|
      venues += group["items"]
    end
    venues.sort! {|a, b| b["stats"]["checkinsCount"] <=> a["stats"]["checkinsCount"]}
    venues = venues.first(10)
    venue_ids = venues.collect do |v|
      v["id"]
    end
    scores = fetch_scores(venue_ids)
    result = scores.zip(venues).collect do |tuple|
      {
        :venue_id => tuple[0]["venue_id"],
        :name => tuple[1]["name"],
        :lat => tuple[1]["location"]["lat"],
        :lon => tuple[1]["location"]["lng"],
        :scores => tuple[0]["scores"]
      }
    end
    result.to_json
  end

  def show
    fs = Foursquare::Venue.new("T4ZOBBXF3AK522ZJHAWZTGELNNFUSQF4BC4HA4XLWJEAVZWD")
    result = fs.search(:ll => "#{params[:lat]},#{params[:lon]}",:query => params[:q])["response"]
    venues = []
    result["groups"].each do |group|
      venues += group["items"]
    end
    venues.sort! {|a, b| b["stats"]["checkinsCount"] <=> a["stats"]["checkinsCount"]}
    venues = venues.first(10)
    venue_ids = venues.collect do |v|
      v["id"]
    end
    scores = fetch_scores(venue_ids)
    result = scores.zip(venues).collect do |tuple|
      {
        :venue_id => tuple[0]["venue_id"],
        :name => tuple[1]["name"],
        :lat => tuple[1]["location"]["lat"],
        :lon => tuple[1]["location"]["lng"],
        :scores => tuple[0]["scores"]
      }
    end
    render :json => result
  end

  def fetch_scores(venue_ids)
    #url = "http://#{venue_ids.join(",")}"
    url = "http://foursquare.xanthas.net/pull_tips.php?#{venue_ids.join(",")}"
    results = JSON.parse(Net::HTTP.get(URI.parse(url)))
  end
end

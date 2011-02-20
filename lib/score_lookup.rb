
module ScoreLookup
  def self.lookup(lat, lon)
    uri = URI.parse(ENV['MONGOHQ_URL'])
    @db = Mongo::Connection.new(ENV['MONGHQ_URL'])["sentiment"]#from_uri(ENV['MONGOHQ_URL'])["sentiment"]
=begin
    cmd = BSON::OrderedHash.new
    cmd['geoNear'] = "places"
    cmd['near'] = [lat, lon]
    cmd['maxDistance'] = 0.05 / 111 #0.05km / 111(kms/degree)
    places = @db.command(cmd)["results"].collect do |p|
      p["result"]
    end
    if places.count > 30
      places
    else
=end
      @places_coll = @db["places"]
      fs = Foursquare::Venue.new("T4ZOBBXF3AK522ZJHAWZTGELNNFUSQF4BC4HA4XLWJEAVZWD")
      result = fs.search(:ll => "#{lat},#{lon}")["response"]
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
      if scores
        result = scores.zip(venues).collect do |tuple|
          category = tuple[1]["categories"][0]["parents"][0] if tuple[1]["categories"][0]
          {
            :venue_id => tuple[0]["venue_id"],
            :name => tuple[1]["name"],
            :lat => tuple[1]["location"]["lat"],
            :lon => tuple[1]["location"]["lng"],
            :category => category,
            :scores => tuple[0]["scores"]
          }
        end
  #      result.each do |r|
  #        @places_coll.insert({:_id => r[:venue_id], :loc_idx => {:lat => r[:lat], :lon => r[:lon]}, :result => r})
  #      end
        result
     end
#   end
  end


  def self.fetch_scores(venue_ids)
    url = "http://foursquare.xanthas.net/pull_tips.php?#{venue_ids.join(",")}"
    results = JSON.parse(Net::HTTP.get(URI.parse(url)))
    if results.count != venue_ids.count
      false
    else
      results
    end
  end
  
end

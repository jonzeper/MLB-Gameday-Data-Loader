require './GamedayFetcher'

year   = '2012'
month  = '06'
day    = '01'
league = 'aaa'

gdf = GamedayFetcher.new
gdf.get_day(league,year,month,day)
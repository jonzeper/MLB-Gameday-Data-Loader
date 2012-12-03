require 'net/http'
require 'hpricot'
require 'fileutils'
require 'benchmark'

DEST_FOLDER = 'data'
GAMEDAY_HOST = 'gd2.mlb.com'
GAMEDAY_BASE_URL = '/components/game/'
CONCURRENT_DOWNLOADS = 3

year   = '2012'
month  = '06'
day    = '01'
league = 'aaa'

$errors = []


class GamedayFetcher
  attr_accessor :errors, :dl_queue

  def initialize()
    self.errors = []
    self.dl_queue = []
  end


  # write_file (path, data)
  #
  # Writes the given data to the file path specified.
  # Does nothing if file already exists or data is empty
  def write_file(path, data)
    return if !data || File.exists?(path)

    # Create any parent directories if they don't exist
    FileUtils.mkdir_p(File.dirname(path))

    # Write data to the file
    File.open(path, "w") { |file| file << gd_data }
  end


  # get_links_on_page (url)
  #
  # Parses the html file at given url and returns a list of all hrefs from <a> tags on the page
  def get_links_on_page(url)
    # puts "Getting links from #{url}"

    # Grab the html file
    response = Net::HTTP.get_response GAMEDAY_HOST, url

    if response.code == '200'
      # If success, parse the file with Hpricot and return just the href attribute from all <a> tags 
      return Hpricot(response.body).search('a').map { |e| e[:href] }
    else
      # If http error, record the error and return an empty array
      self.errors << {url => response.code}
      return []
    end
  end

  # get_day (league, year, month, day)
  #
  # Download all files for given league on given date
  def get_day(league, year, month, day)

    # Initialize an empty array to hold a list of urls to download
    dl_queue = []

    # Determine the root directory for this day
    day_path = "#{league}/year_#{year}/month_#{month}/day_#{day}/"
    day_url = GAMEDAY_BASE_URL + day_path

    # Get the list of all pitchers from this day
    pitcher_files = get_links_on_page(day_url + 'pitchers/').select {|f| f.end_with? 'xml'}
    pitcher_files.each do |xml_filename|

      # This is the source url
      pitcher_url =  "#{day_url}pitchers/#{xml_filename}"

      # And the destination for the local file
      pitcher_file = "#{DEST_FOLDER}#{day_path}pitchers/#{xml_filename}"

      # If the destination file doesn't already exist, add it to the queue
      dl_queue << pitcher_url unless File.exists? pitcher_file
    end

    # Get the root directory for each game played today
    # We'll do each one in its own thread to speed things up
    game_threads = []

    # Game directories start with 'gid_', so just get those
    get_links_on_page(day_url).select {|f| f.start_with? 'gid_' }.each do |game_path|
      game_threads << Thread.new {
        game_url = day_url + game_path
        dl_queue << game_url + 'boxscore.xml'
        dl_queue << game_url + 'game.xml'
        dl_queue << game_url + 'game_events.xml'
        dl_queue << game_url + 'linescore.xml'
        dl_queue << game_url + 'players.xml'

        # Get all the pitchers from this game
        get_links_on_page(game_url + 'pitchers/').select{|f| f.end_with? 'xml' }.each do |xml_filename|
          dl_queue << game_url + 'pitchers/' + xml_filename
        end
      }
    end

    # Download all those games
    game_threads.each {|t| t.join}

    # Create threads for downloading the queued files
    dl_threads = []
    total_dls = dl_queue.length
    completed_dls = 0
    CONCURRENT_DOWNLOADS.times do
      dl_threads << Thread.new {
        while url = dl_queue.shift
          filename = DEST_FOLDER + url

          unless File.exists?(filename)
            # puts "Downloading #{filename} #{total_dls - (completed_dls += 1)} remain"
            
            attempts = 0
            begin
              response = Net::HTTP.get_response GAMEDAY_HOST, url
              if response.code == '200'
                write_file(filename, response.body)
              else
                self.errors << {url => response.code}
                puts "ERROR #{filename} : #{response.code}"
              end
            rescue Exception => e
              if (attempts += 1) < 4
                # puts "Retrying #{filename}"
                retry
              end
              self.errors << {url => e.message}
              puts "ERROR #{filename} : #{e.message}"
            end
          end
        end
      }
    end

    dl_threads.each {|t| t.join}

  end
end

gdf = GamedayFetcher.new
gdf.get_day(league,year,month,day)
require 'net/http'
require 'hpricot'
require 'fileutils'
require 'benchmark'

DEST_FOLDER = 'data'
GAMEDAY_HOST = 'gd2.mlb.com'
GAMEDAY_BASE_URL = '/components/game/'
CONCURRENT_DOWNLOADS = 5

class GamedayFetcher
  attr_accessor :errors, :dl_queue

  def initialize()
    @errors = []
    @dl_queue = []
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
      @errors << {url => response.code}
      return []
    end
  end

  # get_day (league, year, month, day)
  #
  # Download all files for given league on given date
  def get_day(league, year, month, day)

    # Determine the root directory for this day
    day_path = "#{league}/year_#{year}/month_#{month}/day_#{day}/"
    day_url = GAMEDAY_BASE_URL + day_path

    # Get the root directory for each game played today
    # We'll do each one in its own thread to speed things up
    game_threads = []

    # Game directories start with 'gid_', so just get those
    get_links_on_page(day_url).select {|f| f.start_with? 'gid_' }.each do |game_path|
      puts "Found game #{game_path}"
      game_url = day_url + game_path

      # Create a new thread which will download files and crawl subdirs
      game_threads << Thread.new {
        @dl_queue << game_url + 'boxscore.xml'
        @dl_queue << game_url + 'game.xml'
        @dl_queue << game_url + 'linescore.xml'
        @dl_queue << game_url + 'players.xml'

        # Get subdirectory listings (pbp only exists for a couple older years)
        ['pitchers/','batters/','inning/','pbp/'].each do |dir|
          get_links_on_page(game_url + dir).select{|f| f.end_with? 'xml' }.each do |xml_filename|
            @dl_queue << game_url + dir + xml_filename
          end
        end
      }
    end

    # Download all those games
    game_threads.each {|t| t.join}

    # Create threads for downloading the queued files
    print "Downloading #{dl_queue.length} files"

    dl_threads = []
    total_dls = @dl_queue.length
    completed_dls = 0
    CONCURRENT_DOWNLOADS.times do
      dl_threads << Thread.new {
        while url = @dl_queue.shift
          filename = DEST_FOLDER + url

          if File.exists?(filename)
            print '_'
          else
            # puts "Downloading #{filename} #{total_dls - (completed_dls += 1)} remain"
            
            attempts = 0
            begin
              response = Net::HTTP.get_response GAMEDAY_HOST, url
              if response.code == '200'
                write_file(filename, response.body)
                print '.'
              else
                @errors << {url => response.code}
                print '!'
              end
            rescue Exception => e
              if (attempts += 1) < 4
                # puts "Retrying #{filename}"
                retry
              end
              @errors << {url => e.message}
              print '!'
            end
          end
        end
      }
    end

    dl_threads.each {|t| t.join}

    puts ''
    puts "Done with #{@errors.length} errors"
    @errors.each {|e| puts e}
  end
end
require 'net/http'
require 'hpricot' # TODO: Migrate to nokogiri
require 'fileutils'
require 'benchmark'
require 'nokogiri'

require './app/models/team'
require './app/models/stadium'
require './app/models/player'

DEST_FOLDER = 'data'
GAMEDAY_HOST = 'gd2.mlb.com'
GAMEDAY_BASE_URL = '/components/game/'
CONCURRENT_DOWNLOADS = 1

def xml_attributes_to_model_attributes(xml_node, model_class)
  Hash[xml_node.attributes.map {|k,v| [v.name, v.value]}].slice(*model_class.column_names)
end

def update_model_from_xml_node(model_class, xml_node)
  return if xml_node.nil?
  node_attributes = xml_attributes_to_model_attributes(xml_node, model_class)
  instance = model_class.find_or_initialize_by_id(xml_node['id'])
  instance.update_attributes(node_attributes)
  instance.save!
end

def parse_game_xml(game_xml_path)
  xml = Nokogiri::XML(open(game_xml_path))
  team_xml_nodes = xml.xpath('//team')
  for team_xml_node in team_xml_nodes
    update_model_from_xml_node(Team, team_xml_node)
  end
  stadium_xml_node = xml.xpath('//stadium').first
  update_model_from_xml_node(Stadium, stadium_xml_node)
end

def parse_batter_or_pitcher_xml(xml_path)
  xml = Nokogiri::XML(open(xml_path))
  player_xml_node = xml.xpath('//Player').first
  update_model_from_xml_node(Player, player_xml_node)
end

def parse_xml_file(path)
  filename = path.split('/')[-1]
  parent_dir = path.split('/')[-2]
  if filename == 'game.xml'
    parse_game_xml(path)
  elsif %w[batters pitchers].include? parent_dir
    parse_batter_or_pitcher_xml(path)
  end
end

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
    File.open(path, "w") { |file| file << data }
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
            parse_xml_file(filename)
          else
            # puts "Downloading #{filename} #{total_dls - (completed_dls += 1)} remain"

            attempts = 0
            begin
              response = Net::HTTP.get_response GAMEDAY_HOST, url
              if response.code == '200'
                write_file(filename, response.body)
                parse_xml_file(filename)
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
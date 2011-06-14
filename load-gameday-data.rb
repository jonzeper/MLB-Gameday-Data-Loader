require 'net/http'
require 'hpricot'
require 'fileutils'
require 'benchmark'

DEST_FOLDER = './data/'
GAMEDAY_HOST = 'gd2.mlb.com'
GAMEDAY_BASE_URL = '/components/game/mlb/'


year='2010'
month='04'
day='01'

$errors = []

# Writes the gameday data to the file specified.  
# Does not overwrite existing files.
def write_file(file_path, gd_data)
  if gd_data && !File.exists?(file_path)
    FileUtils.mkdir_p(File.dirname(file_path))
    File.open(file_path, "w") do |data|
      data << gd_data
    end
  end
end

# response = Net::HTTP.get_response GAMEDAY_HOST, url

# puts "getting #{url}"
# if response.code == '200'
#   Hpricot(response.body).search('a').each { |a| puts a[:href] }
# else
#   p 'bad'
# end

def get_game(game_path)
end

class GamedayFetcher
  attr_accessor :errors, :dl_queue

  def initialize()
    self.errors = []
    self.dl_queue = []
  end

  def get_links_on_page(url)
    puts "Getting links from #{url}"
    response = Net::HTTP.get_response GAMEDAY_HOST, url
    if response.code == '200'
      return Hpricot(response.body).search('a')
    else
      self.errors << {url => response.code}
      return []
    end
  end

  def get_day(year, month, day)
    day_path = "year_#{year}/month_#{month}/day_#{day}/"
    day_url = GAMEDAY_BASE_URL + day_path

    dl_queue = []

    # get_links_on_page(day_url + 'batters/').each {
    #   |a|
    #   batter_url =  "#{day_url}batters/#{a[:href]}"
    #   batter_file = "#{DEST_FOLDER}#{day_path}batters/#{a[:href]}"

    #   if (!File.exists? batter_file) && (batter_url.end_with?('xml'))
    #     # response2 = Net::HTTP.get_response GAMEDAY_HOST, batter_url
    #     # write_file(batter_file, response2.body)
    #     dl_queue << batter_url
    #   end
    # }

    get_links_on_page(day_url + 'pitchers/').each {
      |a|
      pitcher_url =  "#{day_url}pitchers/#{a[:href]}"
      pitcher_file = "#{DEST_FOLDER}#{day_path}pitchers/#{a[:href]}"

      if (!File.exists? pitcher_file) && (pitcher_url.end_with?('xml'))
        dl_queue << pitcher_url
      end
    }

    game_threads = []
    get_links_on_page(day_url).each {
      |a|
      if a[:href].start_with?('gid_')
        game_threads << Thread.new {
          game_url = day_url + a[:href]
          dl_queue << game_url + 'boxscore.xml'
          dl_queue << game_url + 'game.xml'
          dl_queue << game_url + 'game_events.xml'
          dl_queue << game_url + 'linescore.xml'
          dl_queue << game_url + 'players.xml'

          # get_links_on_page(game_url + 'batters/').each {
          #   |a|
          #   if a[:href].end_with?('xml')
          #     dl_queue << game_url + 'batters/' + a[:href]
          #   end
          # }
          
          # get_links_on_page(game_url + 'inning/').each {
          #   |a|
          #   if a[:href].end_with?('xml')
          #     dl_queue << game_url + 'inning/' + a[:href]
          #   end
          # }

          get_links_on_page(game_url + 'pitchers/').each {
            |a|
            if a[:href].end_with?('xml')
              dl_queue << game_url + 'pitchers/' + a[:href]
            end
          }  
        }
      end
    }
    game_threads.each {|t| t.join}

    total_dls = dl_queue.length
    completed_dls = 0
    dl_threads = []
    3.times do
      dl_threads << Thread.new {
        while url = dl_queue.shift
          filename = DEST_FOLDER + url

          if !File.exists?(filename)
            puts "Downloading #{filename} #{total_dls - (completed_dls += 1)} remain"
            
            attempts = 0
            begin
              response = Net::HTTP.get_response GAMEDAY_HOST, url
              if response.code == '200'
                write_file(filename, response.body)
              else
                self.errors << {url => response.code}
              end
            rescue Exception => e
              if (attempts += 1) < 4
                puts "Retrying #{filename}"
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
gdf.get_day(year,month,day)
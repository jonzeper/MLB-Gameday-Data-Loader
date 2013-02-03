class GamedayParser
  require 'nokogiri'

  require './app/models/team'
  require './app/models/stadium'
  require './app/models/player'
  require './app/models/game'

  def parse_day(league, year, month, day)
    day_path = "data/components/game/#{league}/year_#{year}/month_#{month}/day_#{day}"
    print "Parsing files in #{day_path}..."

    Dir["#{day_path}/**/*"].each do |f|
      parse_xml_file(f) unless File.directory?(f)
      print '.'
    end
    puts "\nDone!"
  end

  private

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

  def parse_linescore_xml(xml_path)
    xml = Nokogiri::XML(open(xml_path))
    game_xml_node = xml.xpath('//game').first
    game_xml_node['mlbam_id'] = game_xml_node.remove_attribute('id').value
    game_attributes = xml_attributes_to_model_attributes(game_xml_node, Game)
    game = Game.find_or_initialize_by_mlbam_id(game_xml_node['mlbam_id'])
    game.update_attributes(game_attributes)
    game.save!
  end

  def parse_xml_file(path)
    filename = path.split('/')[-1]
    parent_dir = path.split('/')[-2]
    if filename == 'game.xml'
      parse_game_xml(path)
    elsif filename == 'linescore.xml'
      parse_linescore_xml(path)
    elsif %w[batters pitchers].include? parent_dir
      parse_batter_or_pitcher_xml(path)
    end
  end
end

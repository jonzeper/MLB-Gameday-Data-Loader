class GamedayParser
  require 'nokogiri'

  require './app/models/team'
  require './app/models/stadium'
  require './app/models/player'
  require './app/models/game'
  require './app/models/at_bat'
  require './app/models/pitch'

  def parse_day(league, year, month, day)
    day_path = "data/components/game/#{league}/year_#{year}/month_#{month}/day_#{day}"
    Dir["#{day_path}/*"].each do |f|
      parse_game_dir(f) if f.split('/')[-1].start_with?('gid')
    end
    puts 'Done!'
  end

  private

  def parse_game_dir(game_dir)
    print "Reading game directory #{game_dir}..."

    game = parse_linescore_xml("#{game_dir}/linescore.xml")
    return unless game.status == 'Final'

    parse_inning_all_xml(game, "#{game_dir}/inning/inning_all.xml")
    parse_game_xml("#{game_dir}/game.xml")

    Dir["#{game_dir}/batters","#{game_dir}/pitchers"].each do |f|
      parse_batter_or_pitcher_xml(f)
    end
    puts
  end

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

  def parse_inning_all_xml(game, xml_path)
    xml = Nokogiri::XML(open(xml_path))
    atbat_xml_nodes = xml.xpath('//atbat')
    for atbat_xml_node in atbat_xml_nodes
      atbat_attributes = xml_attributes_to_model_attributes(atbat_xml_node, AtBat)
      atbat = AtBat.find_or_initialize_by_game_id_and_num(game.id, atbat_attributes['num'])
      atbat.update_attributes(atbat_attributes)

      pitch_xml_nodes = atbat_xml_node.xpath('.//pitch')
      for pitch_xml_node in pitch_xml_nodes
        print '.'

        pitch_xml_node['pitch_type'] = pitch_xml_node.remove_attribute('type').value
        pitch_xml_node['ingame_id'] = pitch_xml_node.remove_attribute('id').value
        pitch_attributes = xml_attributes_to_model_attributes(pitch_xml_node, Pitch)
        pitch = Pitch.find_or_initialize_by_at_bat_id_and_ingame_id(atbat.id, pitch_attributes['ingame_id'])
        pitch.update_attributes(pitch_attributes)
      end
    end
  end

  def parse_linescore_xml(xml_path)
    xml = Nokogiri::XML(open(xml_path))
    game_xml_node = xml.xpath('//game').first
    game_xml_node['mlbam_id'] = game_xml_node.remove_attribute('id').value
    game_attributes = xml_attributes_to_model_attributes(game_xml_node, Game)
    game = Game.find_or_initialize_by_mlbam_id(game_xml_node['mlbam_id'])
    game.update_attributes(game_attributes)
    game.save!
    return game
  end
end

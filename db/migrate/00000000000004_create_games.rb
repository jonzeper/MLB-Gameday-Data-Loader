class CreateGames < ActiveRecord::Migration
  def change
    create_table :games do |t|
      t.string  :mlbam_id
      t.string  :venue
      t.integer :game_pk
      t.time    :time
      t.string  :time_zone
      t.string  :ampm, limit: 2
      t.string  :game_type
      t.string  :original_date
      t.integer :venue_id
      t.integer :scheduled_innings
      t.integer :home_team_id
      t.integer :away_team_id
    end
  end
end

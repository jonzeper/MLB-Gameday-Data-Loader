class CreateAtbatsAndPitches < ActiveRecord::Migration
  def change
    create_table :at_bats do |t|
      t.integer :game_id
      t.integer :num
      t.integer :b
      t.integer :s
      t.integer :o
      t.integer :start_tfs
      t.string  :start_tfs_zulu
      t.integer :batter
      t.string  :stand,    limit: 1
      t.integer :pitcher
      t.string  :p_throws, limit: 1
      t.text    :des
      t.string  :event
    end

    create_table :pitches do |t|
      t.integer :at_bat_id
      t.integer :ingame_id
      t.string  :des
      t.integer :mlbam_id
      t.string  :pitch_type
      t.integer :tfs
      t.string  :tfs_zulu
      t.decimal :x, precision: 5, scale: 2
      t.decimal :y, precision: 5, scale: 2
      t.string  :cc
      t.string  :mt
    end
  end
end

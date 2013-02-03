class Init < ActiveRecord::Migration
  def change
    create_table :teams do |t|
      t.string  :code,   limit: 3
      t.string  :abbrev, limit: 3
      t.string  :name
      t.string  :name_full
      t.string  :name_brief
      t.integer :division_id
      t.integer :league_id
      t.string  :league, limit: 3
    end
  end
end

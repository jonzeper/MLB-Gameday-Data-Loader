class CreatePlayers < ActiveRecord::Migration
  def change
    create_table :players do |t|
      t.string  :team,   limit: 3
      t.string  :pos,    limit: 2
      t.string  :first_name
      t.string  :last_name
      t.integer :jersey_number
      t.string  :bats,   limit: 1
      t.string  :throws, limit: 1
      t.date    :dob
    end
  end
end

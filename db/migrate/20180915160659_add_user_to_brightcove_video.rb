# frozen_string_literal: true
class AddUserToBrightcoveVideo < ActiveRecord::Migration[5.2]
  def change
    add_column :brightcove_videos, :user_id, :integer
  end
end

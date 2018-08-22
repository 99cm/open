# frozen_string_literal: true

class AddApiKeyToSpreeUsers < ActiveRecord::Migration[5.2]
  def change
    unless defined?(User)
      add_column :spree_users, :api_key, :string, limit: 40
    end
  end
end

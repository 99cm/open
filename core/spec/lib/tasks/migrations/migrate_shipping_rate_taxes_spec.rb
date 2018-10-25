# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'open:migrations:migrate_shipping_rate_taxes' do
  describe 'up' do
    include_context(
      'rake',
      task_path: Spree::Core::Engine.root.join('lib/tasks/migrations/migrate_shipping_rate_taxes.rake'),
      task_name: 'open:migrations:migrate_shipping_rate_taxes:up',
    )

    it 'runs' do
      expect { task.invoke }.to output(
        "Adding persisted tax notes to historic shipping rates ... Success.\n"
      ).to_stdout
    end
  end
end

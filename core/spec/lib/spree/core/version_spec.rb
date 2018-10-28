# frozen_string_literal: true

RSpec.describe Spree do
  describe '.open_version' do
    it "returns a string" do
      expect(Spree.open_version).to be_a(String)
    end
  end

  describe '.open_gem_version' do
    it "returns a Gem::Version" do
      expect(Spree.open_gem_version).to be_a(Gem::Version)
    end

    it "can be compared" do
      expect(Spree.open_gem_version).to be > Gem::Version.new("1.0")
    end
  end
end

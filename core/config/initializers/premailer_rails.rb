if Gem.loaded_specs['premailer-rails'].version >= Gem::Version.create('1.10.2')
  Premailer::Rails.config[:strategies] = [:filesystem, :network, :asset_pipeline]
end
require 'json'


unified_hash = Dir.glob('data/*.json').map do |versionFile|
  { :version => versionFile[5,5],
    :rules => JSON.parse(File.open(versionFile, 'r').read) }
end

File.open("data.json", 'w') do |file|
  file.write(unified_hash.to_json)
end
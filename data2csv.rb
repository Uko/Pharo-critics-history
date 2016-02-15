require 'json'
require 'csv'



CSV.open('data.csv', 'w') do |csv|

  csv << ['version', 'rule name', 'rule severity', 'rule group', 'package', 'entity']


  Dir.glob('data/*.json') do |versionFile|
    version = versionFile[5,5]

    version_data = JSON.parse(File.open(versionFile, 'r').read)

    version_data.each do |rule|

      rule['critics'].each do |critic|

        csv << [version, rule['name'], rule['severity'], rule['group'], critic['package'], critic['name']]

      end
    end
  end
end


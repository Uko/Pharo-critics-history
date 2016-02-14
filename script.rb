#!/usr/bin/env ruby

require 'rubygems'
require 'open-uri'
require 'fileutils'
require 'zip'
require 'json'


def unzip_file (file, destination = file.chomp('.zip'))
  Zip::File.open(file) { |zip_file|
    zip_file.each { |f|
      f_path=File.join(destination, f.name)
      FileUtils.mkdir_p(File.dirname(f_path))
      zip_file.extract(f, f_path) unless File.exist?(f_path)
    }
  }
end

def download_image (name)
  File.open(name, 'wb') do |saved_file|
    # the following "open" is provided by open-uri
    open("http://files.pharo.org/image/50-preSpur/#{name}", 'rb') do |read_file|
      saved_file.write(read_file.read)
    end
  end
end

def remove_image_files(image_zip_name)
  FileUtils.rm_r [image_zip_name, image_zip_name.chomp('.zip')]
end

def pharo_preamble(version_string)
  return "./pharo #{version_string}/Pharo-#{version_string}.image --no-default-preferences eval "
end

def get_critics(rule, image)
  script = "#{rule} new in: [ :rule |
    RBSmalllintChecker runRule: rule.
    (rule critics collect: [ :entity |
      entity package name, '}{', entity name ]) asArray joinUsing: String lf ]"

  critics = `#{pharo_preamble image} "#{script}"`.chomp[1..-2].split("\n")

  critics.map do |critic_str|
    critic = critic_str.split('}{')
    { :package => critic[0], :name => critic[1] }
  end
end

def process_rule(rule, image)
  return {
      :name => rule,
      :severity =>  `#{pharo_preamble image} '#{rule} new severity asString'`.chomp[1..-2],
      :group => `#{pharo_preamble image} '#{rule} new group asString'`.chomp[1..-2],
      :critics => get_critics(rule, image)
  }

end

def get_image_rules(image_name)
  script = '(RBCompositeLintRule allGoodRules leaves collect: #class) joinUsing: String space'
  rules = `#{pharo_preamble image_name} '#{script}'`.chomp[1..-2].split(' ')
  rules = rules[0, 10]
  rules.map{ |rule| process_rule rule, image_name }
end




images_uri = URI.parse('http://files.pharo.org/image/50-preSpur/')
images_uri.read.scan(/50\d{3}\.zip/)

def install_vm
  `./vm50.sh`
end

def clean_up_vm
  FileUtils.rm_r %w(pharo pharo-ui pharo-vm)
end

def process_image(image_zip_name)

  image_name = image_zip_name.chomp('.zip')

  return if File.file?("data/#{image_name}.json")

  download_image image_zip_name
  unzip_file image_zip_name


  critic_dict = get_image_rules image_name

  File.open("data/#{image_name}.json", 'w') do |file|
    file.write(critic_dict.to_json)
  end

  remove_image_files image_zip_name
end




install_vm

images_uri.read.scan(/50\d{3}\.zip/).reverse.each do |image|

  process_image image

end

clean_up_vm
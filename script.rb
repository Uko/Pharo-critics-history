#!/usr/bin/env ruby

require 'rubygems'
require 'open-uri'
require 'fileutils'
require 'zip'
require 'json'
require 'optparse'

@uniform_mode = false
@max_processes = 4

OptionParser.new do |opts|
  opts.banner = 'This stuf runs a lot of pharo images'

  opts.on('-t', '--threads NUMBER', 'Number of threads to use') do |num_processes|
    @max_processes =  Integer(num_processes)
  end

  opts.on('-u', '--[no-]uniform', 'Uniform mode (load latest rules into each image)') do |uniform|
    @uniform_mode = uniform
  end
end.parse!


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
  image_data = open("http://files.pharo.org/image/50-preSpur/#{name}", 'rb').read

  File.open(name, 'wb') do |saved_file|
      saved_file.write(image_data)
  end
end

def remove_image_files(image_zip_name)
  FileUtils.rm_r [image_zip_name, image_zip_name.chomp('.zip')]
end

def pharo_preamble(version_string)
  "./pharo #{version_string}/Pharo-#{version_string}.image --no-default-preferences eval "
end

def load_latest_rules(image_name)
  `#{pharo_preamble image_name} "Gofer it smalltalkhubUser: 'Pharo' project: 'Pharo50'; version: 'Manifest-Core-TheIntegrator.236'; load"`
end

def get_critics(rule, image)
  script = "#{rule} new in: [ :rule |
    RBSmalllintChecker runRule: rule.
    (rule critics collect: [ :entity |
      entity package name, '}{', entity name ]) asArray joinUsing: String lf ]"

  result=`#{pharo_preamble image} "#{script}"`

  if $?.to_i == 0
    critics = result.chomp[1..-2].split("\n")

    critics.map do |critic_str|
      critic = critic_str.split('}{')
      { :package => critic[0], :name => critic[1] }
    end
  else
    []
  end
  
end

def process_rule(rule, image)
   {
      :name => rule,
      :severity =>  `#{pharo_preamble image} '#{rule} new severity asString'`.chomp[1..-2],
      :group => `#{pharo_preamble image} '#{rule} new group asString'`.chomp[1..-2],
      :critics => get_critics(rule, image)
  }

end

def get_image_rules(image_name)
  script = '(RBCompositeLintRule allGoodRules leaves collect: #class) joinUsing: String space'
  rules = `#{pharo_preamble image_name} '#{script}'`.chomp[1..-2].split(' ')
  rules.map{ |rule| process_rule rule, image_name }
end

def data_dir
  @uniform_mode ? 'data-uni' : 'data'
end


def install_vm
  `./vm50.sh`
end

def clean_up_vm
  FileUtils.rm_r %w(pharo pharo-ui pharo-vm)
end

def process_image(image_zip_name)

  image_name = image_zip_name.chomp('.zip')

  return if File.file?("#{data_dir}/#{image_name}.json")

  download_image image_zip_name
  unzip_file image_zip_name

  load_latest_rules(image_name) if @uniform_mode

  critic_dict = get_image_rules image_name

  FileUtils.mkdir_p 'data'
  File.open("#{data_dir}/#{image_name}.json", 'w') do |file|
    file.write(critic_dict.to_json)
  end

  remove_image_files image_zip_name
end





install_vm

images_uri = URI.parse('http://files.pharo.org/image/50-preSpur/')
images_uri.read.scan(/50\d{3}\.zip/).uniq.reverse.each_slice(@max_processes) do |images|

  images.each do |image|
    fork { process_image image }
  end

  Process.waitall

end

clean_up_vm
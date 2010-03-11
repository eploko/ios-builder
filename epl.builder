#!/usr/bin/env ruby

require 'rubygems'
require 'fileutils'
require 'term/ansicolor'
require 'tmpdir'
require 'yaml'

include Term::ANSIColor

def main
  banner
  check_args
  config = setup
  print_config config
  Dir.mkdir config['tmp_dir']
  clone_repo(config['repo'], config['src_dir'])
  update_submodules(config['src_dir'])
  bump_versions(config)
  xcodebuild(config['src_dir'], config['project'], config['sdk'], config['target'], config['configuration'])
  copy_payload(config)
  commit_build(config)
  zip_build(config)
  copy_build(config)
  FileUtils.rm_rf config['tmp_dir']
  success "All done!"
end

def banner
  puts "Plokodelika iPhone App Builder v1.0"
  puts "Copyright © 2010 Andrey Subbotin <andrey@subbotin.me>"
end

def check_args 
  if (ARGV.length == 0)
    puts "Usage: epl.builder <config-file.yml>"
    exit 1
  end
end

def setup
  config = YAML.load_file(ARGV[0])
  config['tmp_dir'] = File.join Dir.tmpdir, "epl.builder.#{$$}"
  config['src_dir'] = File.join config['tmp_dir'], 'src'
  config['build_results_dir'] = File.join config['src_dir'], 'build', 
                                "#{config['configuration']}-#{config['build_dir_suffix']}"
  config['payload_target'] = File.join config['tmp_dir'], 'payload'
  return config
end

def print_config(config)
  # Print out settings
  status "CONFIG"
  config.keys.sort.each do |k|
    puts "#{k.upcase}: #{config[k]}"
  end
end

def exe(cmd)
  print magenta, "CMD: '#{cmd}'", reset, "\n"  
  system cmd
end

def status(msg)
  print blue, "--- #{msg} ---", reset, "\n"  
end

def error(msg)
  print red, bold, 'ERROR: ', msg, reset, "\n"
  exit 1
end

def success(msg)
  print green, bold, 'SUCCESS: ', msg, reset, "\n"
end

def clone_repo(repo, src_dir)
  status 'CLONING THE REPO'
  rc = exe "git clone '#{repo}' '#{src_dir}'"
  error "Failed to clone the repo!" unless rc
end

def update_submodules(src_dir)
  status "UPDATING SUBMODULES @ #{src_dir}"
  Dir.chdir src_dir
  rc = exe 'git submodule init'
  error "Failed to init submodules!" unless rc
  rc = exe 'git submodule update'
  error "Failed to update submodules!" unless rc
  submodules = []
  `git submodule`.split("\n").each do |sm| sms = sm.split(" "); submodules << sms[1] ; end
  submodules.each do |submodule|
    update_submodules File.join(src_dir, submodule)
  end
  Dir.chdir src_dir
end

def xcodebuild(src_dir, project, sdk, target, configuration)
  Dir.chdir src_dir  
  status "BUILDING"
  rc = exe "xcodebuild -project '#{project}' -sdk '#{sdk}' -target '#{target}' -configuration '#{configuration}'"
  error "Failed to build the project!" unless rc
  Dir.chdir src_dir
end

def copy_payload(config)
  status "COPYING PAYLOAD CONTENT"
  Dir.mkdir config['payload_target']
  if config['mode'] == 'appstore'
    FileUtils.cp_r Dir.glob(File.join(config['build_results_dir'], '*.app')), 
                  config['payload_target'], :verbose => true
  else
    FileUtils.cp_r Dir.glob(File.join(config['payload'], '*')), 
                   config['payload_target'], :verbose => true
    FileUtils.cp_r Dir.glob(File.join(config['build_results_dir'], '*')), 
                  config['payload_target'], :verbose => true
  end
end

def bump_versions(config)
  status "BUMPING VERSIONS"
  rc = exe 'agvtool bump -all'
  error "Failed to bump the build number!" unless rc
  rc = exe "agvtool new-marketing-version #{config['marketing_version']}"
  error "Failed to set the marketing version!" unless rc
  config['current_version'] = `agvtool what-version -terse`.chomp!
  config['current_marketing_version'] = `agvtool what-marketing-version -terse1`.chomp!
end

def commit_build(config)  
  # commit
  status "COMMITING BUILD"
  rc = exe "git commit -a -m 'Successful build #{config['current_version']} for v#{config['current_marketing_version']}'"
  error "Failed to commit the build!" unless rc
  
  # remember the SHA1 for the build
  config['git_sha'] = `git rev-parse --short HEAD`.chomp!
  
  # tag the build
  status "TAGGING BUILD"
  config['git_tag'] = "v#{config['current_marketing_version']}-b#{config['current_version']}";
  rc = exe "git tag -s -m 'Tagging version #{config['current_marketing_version']}, build #{config['current_version']}' " +
              "'#{config['git_tag']}'"
  error "Failed to tag the build!" unless rc
  
  # pull whatever is there
  status "PULLING ORIGIN MASTER"
  rc = exe "git pull origin master"
  error "Failed to pull origin master!" unless rc

  # push whatever is here
  status "PUSHING ORIGIN MASTER"
  rc = exe "git push origin master"
  error "Failed to push origin master!" unless rc

  # push the tag
  status "PUSHING THE NEW TAG"
  rc = exe "git push origin tag '#{config['git_tag']}'"
  error "Failed to push the tag!" unless rc
end

def zip_build(config)
  status "ZIPPING THE BUILD"
  Dir.chdir config['payload_target']
  config['buildbase'] = ("#{config['zip_prefix']}_#{config['current_marketing_version']}_" +
                      "#{config['configuration']}_b#{config['current_version']}_#{config['git_sha']}_" + 
                      Time.now.strftime('%Y%m%d')).gsub('.', '_').gsub('-', '_')
  config['zipname'] = config['buildbase'] + '.zip'
  config['zipname_absolute'] = File.join config['tmp_dir'], config['zipname']
  exe "zip -r -9 '#{config['zipname_absolute']}' ."
  exe "mv '#{config['zipname_absolute']}' ~/Desktop"
end

def copy_build(config)
  status "POPULATING BUILDS FOLDER"
  build_folder = File.join(config['builds_folder'], config['buildbase'])
  exe "mkdir -p \"#{build_folder}\""
  FileUtils.cp_r Dir.glob(File.join(config['build_results_dir'], '*')), 
                 build_folder, :verbose => true
end

main
exit 0

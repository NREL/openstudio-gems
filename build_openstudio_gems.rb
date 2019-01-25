require 'fileutils'
require 'time'
require 'rbconfig'

install_dir = ARGV[0]
tar_exe = ARGV[1]
expected_ruby_version = ARGV[2]

def system_call(cmd)
  puts cmd
  system(cmd)
end

ENV['PATH'] = "#{ENV['PATH']}#{File::PATH_SEPARATOR}#{File.dirname(tar_exe)}"

if RUBY_VERSION != expected_ruby_version
  raise "Incorrect Ruby version ${RUBY_VERSION} used, expecting #{expected_ruby_version}"
end

ruby_gem_dir = Gem.default_dir.split('/').last
if ruby_gem_dir.nil?
  fail "Cannot determine default gem dir"
end

if /win/.match(RUBY_PLATFORM) || /mingw/.match(RUBY_PLATFORM)
  ENV['PATH'] = "#{ENV['PATH']};C:\\Program Files\\Git\\cmd"
end

if File.exists?(install_dir)
  FileUtils.rm_rf(install_dir)
end

bundle_version = nil
File.open('Gemfile', 'r') do |f|
  while line = f.gets
    if md = /gem 'bundler',(.*)/.match(line)
      bundle_version = md[1].strip
    end
  end
end
if bundle_version.nil?
  raise "Cannot determine bundle version"
end
bundle_version = bundle_version.gsub(/['=~> ]/, '')

puts "Installing bundler #{bundle_version}"
system_call("gem install bundler --version #{bundle_version} --install-dir='#{install_dir}/ruby/#{ruby_gem_dir}'")

ENV['BUNDLE_WITHOUT'] = 'test'
bundle_exe = File.join("#{install_dir}/ruby/#{ruby_gem_dir}", 'bin', 'bundle')

if !File.exists?(bundle_exe)
  raise "Required bundle executable not found"
end

if File.exists?('Gemfile.lock')
  puts 'Removing Gemfile.lock'
  FileUtils.rm('Gemfile.lock')
end

system_call("#{bundle_exe} _#{bundle_version}_ install --without=test --path='#{install_dir}'")

system_call("#{bundle_exe} _#{bundle_version}_ lock --add_platform ruby")

platforms_to_remove = ['mri', 'mingw', 'x64_mingw', 'x64-mingw32', 'rbx', 'jruby', 'mswin', 'mswin64']
platforms_to_remove.each do |platform|
  system_call("#{bundle_exe} _#{bundle_version}_ lock --remove_platform #{platform}")
end

FileUtils.rm_rf("#{install_dir}/ruby/#{ruby_gem_dir}/cache")

FileUtils.rm_rf("./.bundle")

standards_gem_dir = nil
workflow_gem_dir = nil
Dir.glob("#{install_dir}/ruby/#{ruby_gem_dir}/bundler/gems/*").each do |f|
  if /openstudio-standards/i.match(f)
    standards_gem_dir = f
  elsif /openstudio-workflow/i.match(f)
    workflow_gem_dir = f
  end
end
Dir.glob("#{install_dir}/ruby/#{ruby_gem_dir}/gems/*").each do |f|
  if /openstudio-standards/i.match(f)
    standards_gem_dir = f
  elsif /openstudio-workflow/i.match(f)
    workflow_gem_dir = f
  end
end

puts "standards_gem_dir = #{standards_gem_dir}"
puts "workflow_gem_dir = #{workflow_gem_dir}"

# clean up standards gem
FileUtils.rm_rf("#{standards_gem_dir}/.git") # If installed from Github
FileUtils.rm_rf("#{standards_gem_dir}/.circleci") # If installed from Github
FileUtils.rm_rf("#{standards_gem_dir}/.vscode") # If installed from Github
FileUtils.rm_rf("#{standards_gem_dir}/test") # If installed from Github
FileUtils.rm_rf("#{standards_gem_dir}/docs") # If installed from Github
# Remove Canadian weather files
Dir.glob("#{standards_gem_dir}/data/weather/*").each do |f|
  if /CAN_/.match(f)
    FileUtils.rm_f(f)
  end
end

# clean up workflow gem
FileUtils.rm_rf("#{workflow_gem_dir}/.git")
FileUtils.rm_rf("#{workflow_gem_dir}/spec")
FileUtils.rm_rf("#{workflow_gem_dir}/test")

# copy Gemfile and Gemfile.lock
FileUtils.cp('Gemfile', "#{install_dir}/.")
FileUtils.cp('Gemfile.lock', "#{install_dir}/.")

Dir.chdir("#{install_dir}/..")

new_file_name = "openstudio-gems-#{DateTime.now.strftime("%Y%m%d")}.tar.gz"
system_call("\"#{tar_exe}\" -zcvf \"#{new_file_name}\" \"openstudio-gems\"")

puts
puts "You need to manually upload #{new_file_name} to S3:openstudio-resources/dependencies/"
puts "Also, you will need to update openstudiocore/CMakeLists.txt with the new file name and the md5 hash (call `md5 #{new_file_name}` or `md5sum #{new_file_name}` to get hash)"
puts
require 'fileutils'
require 'time'
require 'rbconfig'

def system_call(cmd)
  new_env = {}
  new_env['BUNDLER_ORIG_MANPATH'] = nil
  new_env['BUNDLER_ORIG_PATH'] = nil
  new_env['BUNDLER_VERSION'] = nil
  new_env['BUNDLE_BIN_PATH'] = nil
  new_env['BUNDLE_GEMFILE'] = nil
  new_env['RUBYLIB'] = nil
  new_env['RUBYOPT'] = nil
  new_env['BUNDLE_PATH'] = nil

  puts cmd
  system(new_env, cmd)
end

def make_package(install_dir, tar_exe, expected_ruby_version)

  #ENV.each_pair do |k,v|
  #  puts "'#{k}' = '#{v}'"
  #end

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
  File.open('openstudio-gems.gemspec', 'r') do |f|
    while line = f.gets
      if md = /add_development_dependency 'bundler',(.*)/.match(line)
        bundle_version = md[1].strip
      end
    end
  end
  if bundle_version.nil?
    raise "Cannot determine bundle version"
  end
  bundle_version = bundle_version.gsub(/['=~> ]/, '')

  puts "Installing bundler #{bundle_version}"
  system_call("gem install bundler --version #{bundle_version}")
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

  # DLM: don't remove system platforms, that creates problems when running bundle on the command line
  # these will be removed later
  platforms_to_remove = ['mri', 'mingw', 'x64_mingw', 'x64-mingw32', 'rbx', 'jruby', 'mswin', 'mswin64']
  #platforms_to_remove.each do |platform|
  #  system_call("#{bundle_exe} _#{bundle_version}_ lock --remove_platform #{platform}")
  #end

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

  # copy gemspec, Gemfile, and Gemfile.lock
  FileUtils.cp('openstudio-gems.gemspec', "#{install_dir}/.")
  FileUtils.cp('Gemfile', "#{install_dir}/.")
  FileUtils.cp('Gemfile.lock', "#{install_dir}/.")

  # remove platforms here
  gemfile_lock = ''
  File.open("#{install_dir}/Gemfile.lock", 'r') do |file|
    while line = file.gets
      skip = false
      platforms_to_remove.each do |platform|
        if /^\s*#{platform}/.match(line)
          skip = true
          puts "Skipping: #{line}"
        end
      end
      gemfile_lock += line if !skip
    end
  end
  File.open("#{install_dir}/Gemfile.lock", 'w') do |file|
    file.puts(gemfile_lock)
    # make sure data is written to the disk one way or the other
    begin
      file.fsync
    rescue
      file.flush
    end
  end

  Dir.chdir("#{install_dir}/..")

  new_file_name = "openstudio3-gems-minimal-#{DateTime.now.strftime("%Y%m%d")}.tar.gz"

  FileUtils.rm_f(new_file_name) if File.exists?(new_file_name)

  system_call("\"#{tar_exe}\" -zcvf \"#{new_file_name}\" \"openstudio-gems\"")

  puts
  puts "You need to manually upload #{new_file_name} to S3:openstudio-resources/dependencies/"
  puts "Also, you will need to update openstudiocore/CMakeLists.txt with the new file name and the md5 hash (call `md5 #{new_file_name}` or `md5sum #{new_file_name}` to get hash)"
  puts

end

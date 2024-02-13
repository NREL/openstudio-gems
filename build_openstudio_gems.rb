require 'fileutils'
require 'time'
require 'rbconfig'
require 'open3'

def system_call(cmd)
  # This will just unset env variables if defined
  new_env = {}
  new_env['BUNDLER_ORIG_MANPATH'] = nil
  new_env['BUNDLER_ORIG_PATH'] = nil
  new_env['BUNDLER_VERSION'] = nil
  new_env['BUNDLE_BIN_PATH'] = nil
  new_env['BUNDLE_GEMFILE'] = nil
  new_env['RUBYLIB'] = nil
  new_env['RUBYOPT'] = nil

  # BUNDLE_PATH, BUNDLE_WITHOUT and BUILD_BUILD__SQLITE3 are set correctly from
  # conanfile, so do not touch them
  # new_env['BUNDLE_PATH'] = "./openstudio-gems"
  # new_env['BUNDLE_WITHOUT'] = "test"
  # new_env['BUNDLE_BUILD__SQLITE3'] = "--enable-system-libraries --with-pkg-config=pkgconf"

  puts cmd
  system(new_env, cmd)
end

def make_package(install_dir, tar_exe, expected_ruby_version, bundler_version)

  #ENV.each_pair do |k,v|
  #  puts "'#{k}' = '#{v}'"
  #end

  if ENV['BUNDLE_PATH'].nil?
    raise "BUNDLE_PATH is nil, did you forget to load conanbuild?"
  end

  if RUBY_VERSION != expected_ruby_version
    raise "Incorrect Ruby version #{RUBY_VERSION} used, expecting #{expected_ruby_version}"
  end

  ruby_gem_dir = Gem.default_dir.split('/').last
  if ruby_gem_dir.nil?
    fail "Cannot determine default gem dir"
  end

  # TODO: why?
  if /win/.match(RUBY_PLATFORM) || /mingw/.match(RUBY_PLATFORM)
    ENV['PATH'] = "#{ENV['PATH']};C:\\Program Files\\Git\\cmd"
  end

  if /mswin/.match(RUBY_PLATFORM)
    platform_prefix = "windows"
  elsif /darwin/.match(RUBY_PLATFORM)
    if /arm64/.match(RUBY_PLATFORM)
      platform_prefix = "darwin_arm64"
    else
      platform_prefix = "darwin"
    end
  elsif /linux/.match(RUBY_PLATFORM)
    if /aarch64/.match(RUBY_PLATFORM)
      platform_prefix = "linux_arm64"
    else
      platform_prefix = "linux"
    end
  else
    puts RUBY_PLATFORM  + " is an unsupported platform"
    platform_prefix = ""
  end


  if File.exist?(install_dir)
    FileUtils.rm_rf(install_dir)
  end

  puts "Installing bundler #{bundler_version}"
  # TODO: Why twice?
  system_call("gem install bundler --version #{bundler_version}")
  system_call("gem install bundler --version #{bundler_version} --install-dir='#{install_dir}/ruby/#{ruby_gem_dir}'")

  # ENV['BUNDLE_WITHOUT'] = 'test'
  # ENV['BUNDLE_PATH'] = install_dir

  bundle_exe = File.join("#{install_dir}/ruby/#{ruby_gem_dir}", 'bin', 'bundle')
  bundle_cmd = "ruby #{bundle_exe} _#{bundler_version}_"
  if !File.exist?(bundle_exe)
    raise "Required bundle executable not found"
  end

  if File.exist?('Gemfile.lock')
    puts 'Removing Gemfile.lock'
    FileUtils.rm('Gemfile.lock')
  end

  puts "=" * 33 + " bundle config " + "=" * 32
  system_call("#{bundle_cmd} config")
  puts "=" * 80

  system_call("#{bundle_cmd} install")

  lib_ext = RbConfig::CONFIG['LIBEXT']
  libs = Dir.glob("./openstudio-gems/**/*.#{lib_ext}")
  lib_names_woext = Set.new(libs.map{|lib| File.basename(lib, File.extname(lib)) })
  expected = Set.new(["jaro_winkler_ext", "libll", "liboga", "msgpack", "pycall", "sqlite3_native", "unf_ext"])
  if lib_names_woext != expected
    puts "Missing expected extensions: #{expected - lib_names_woext}"
    puts "Extra unexpected extensions: #{lib_names_woext - expected}"
    raise "Unexpected results with native extensions"
  end

  system_call("#{bundle_cmd} lock --add_platform ruby")

  # DLM: don't remove system platforms, that creates problems when running bundle on the command line
  # these will be removed later
  platforms_to_remove = ['mri', 'mingw', 'x64_mingw', 'x64-mingw32', 'rbx', 'jruby', 'mswin', 'mswin64']
  #platforms_to_remove.each do |platform|
  #  system_call("#{bundle_exe} _#{bundler_version}_ lock --remove_platform #{platform}")
  #end

  FileUtils.rm_rf("#{install_dir}/ruby/#{ruby_gem_dir}/cache")

  # Remove .git, .github, .gitiginore
  Dir.glob("#{install_dir}/ruby/#{ruby_gem_dir}/**/.git*").each do |f|
    FileUtils.rm_rf(f)
  end

  Dir.glob("#{install_dir}/ruby/#{ruby_gem_dir}/gems/*/spec")

  folders_to_remove = ["doc", "docs", "test", "spec", "specs"]
  folders_to_remove.each do |folder|
    Dir.glob("#{install_dir}/ruby/#{ruby_gem_dir}/gems/*/#{folder}/").each {|f| FileUtils.rm_rf(f) }
    Dir.glob("#{install_dir}/ruby/#{ruby_gem_dir}/bundler/gems/*//#{folder}/").each {|f| FileUtils.rm_rf(f) }
  end

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

  if ENV['DATE'].nil?
    date = DateTime.now.strftime("%Y%m%d")
  else
    date = ENV['DATE']
  end
  # TODO: at some point we should provide a proper cmake gems-config.cmake
  new_file_name = "openstudio3-gems-#{date}-#{platform_prefix}-#{expected_ruby_version}.tar.gz"
  File.open("#{install_dir}/version.txt", 'w') do |f|
    f.puts new_file_name
  end

  # Globbing through 6000 files in cmake everytime we rerun configure takes way
  # too much time (the worst being windows), so prepare a list for embedding
  extensions_to_glob = ["rb", "data", "erb", "js", "css", "gif", "png", "html", "idf", "osm", "epw", "ddy", "stat", "csv", "json", "gemspec", "gz", "yml"]
  puts "Globbing for #{extensions_to_glob} to add it to export-extensions.cmake"
  gemEmbbedPaths = Dir.glob("**/*.{#{extensions_to_glob.join(",")}}", base: install_dir)
  puts "Found #{gemEmbbedPaths.size} files"
  #gemEmbbedPaths = all_files.map{|f| (Pathname.new(f).relative_path_from install_dir).to_s }
  gemFiles = gemEmbbedPaths.map{|f| "\"${OPENSTUDIO_GEMS_DIR}/#{f}\""}
  exports_file_name = "#{install_dir}/export-extensions.cmake"
  File.open(exports_file_name, "a") do |f|
    f.puts "set(gemsFiles"
    gemFiles.each {|x| f.puts "  #{x}"}
    f.puts ")"
    f.puts
    f.puts "set(gemEmbbedPaths"
    gemEmbbedPaths.each {|x| f.puts "  #{x}"}
    f.puts ")"
  end

  # TODO: no longer chdir'ing, so this shouldn't be necessary
  puts "Current directory: #{Dir.pwd}"
  Dir.chdir("#{install_dir}/..")

  FileUtils.rm_f(new_file_name) if File.exist?(new_file_name)

  system_call("\"#{tar_exe}\" -zcvf \"#{new_file_name}\" \"openstudio-gems\"")

  puts
  puts "You need to manually upload #{new_file_name} to S3:openstudio-resources/dependencies/"
  puts "Also, you will need to update OpenStudio/CMakeLists.txt with the new file name and the md5 hash (call `md5 #{new_file_name}` or `md5sum #{new_file_name}` to get hash)"
  puts
  cmd = nil
  if platform_prefix == 'Windows'
    cmd = "certutil -hashfile \"#{new_file_name}\" MD5"
  else
    cmd = "md5sum \"#{new_file_name}\""
  end

  Open3.popen3(cmd) do |stdin, stdout, stderr, wait_thr|
    stdout = stdout.gets(nil)
    stderr = stderr.gets(nil)
    result = wait_thr.value.exitstatus
    if result == 0
      puts "#{stdout}"
    else
      puts "Something went wrong, exitcode=#{result}"
      puts "stdout=#{stdout}"
      puts "stderr=#{stderr}"
    end
  end
end

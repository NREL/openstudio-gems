require 'fileutils'
require 'time'
require 'rbconfig'
require 'open3'

def system_call(cmd, is_final = false)
  # This will just unset env variables if defined
  new_env = {}
  new_env['BUNDLER_ORIG_MANPATH'] = nil
  new_env['BUNDLER_ORIG_PATH'] = nil
  new_env['BUNDLER_VERSION'] = nil
  new_env['BUNDLE_BIN_PATH'] = nil
  new_env['BUNDLE_GEMFILE'] = nil
  new_env['RUBYLIB'] = nil
  new_env['RUBYOPT'] = nil
  new_env['FINAL_PACKAGE'] = 'true' if is_final

  # BUNDLE_PATH, BUNDLE_WITHOUT and BUILD_BUILD__SQLITE3 are set correctly from
  # conanfile, so do not touch them
  # new_env['BUNDLE_PATH'] = "./openstudio-gems"
  # new_env['BUNDLE_WITHOUT'] = "test"
  # new_env['BUNDLE_BUILD__SQLITE3'] = "--enable-system-libraries --with-pkg-config=pkgconf"

  puts cmd
  system(new_env, cmd)
end

def make_package(install_dir, tar_exe, expected_ruby_version, bundler_version)
  # ENV.each_pair do |k,v|
  #  puts "'#{k}' = '#{v}'"
  # end

  raise 'BUNDLE_PATH is nil, did you forget to load conanbuild?' if ENV['BUNDLE_PATH'].nil?

  if RUBY_VERSION != expected_ruby_version
    raise "Incorrect Ruby version #{RUBY_VERSION} used, expecting #{expected_ruby_version}"
  end

  ruby_gem_dir = Gem.default_dir.split('/').last
  raise 'Cannot determine default gem dir' if ruby_gem_dir.nil?

  # TODO: why?
  if /win/.match(RUBY_PLATFORM) || /mingw/.match(RUBY_PLATFORM)
    ENV['PATH'] = "#{ENV['PATH']};C:\\Program Files\\Git\\cmd"
  end

  is_unix = true
  if /mswin/.match(RUBY_PLATFORM)
    platform_prefix = 'windows'
    is_unix = false
  elsif /darwin/.match(RUBY_PLATFORM)
    platform_prefix = if /arm64/.match(RUBY_PLATFORM)
                        'darwin_arm64'
                      else
                        'darwin'
                      end
  elsif /linux/.match(RUBY_PLATFORM)
    platform_prefix = if /aarch64/.match(RUBY_PLATFORM)
                        'linux_arm64'
                      else
                        'linux'
                      end
  else
    puts RUBY_PLATFORM + ' is an unsupported platform'
    platform_prefix = ''
  end

  FileUtils.rm_rf(install_dir) if File.exist?(install_dir)

  puts "Installing bundler #{bundler_version}"
  # TODO: Why twice?
  system_call("gem install bundler --version #{bundler_version}")
  system_call("gem install bundler --version #{bundler_version} --install-dir='#{install_dir}/ruby/#{ruby_gem_dir}'")

  # ENV['BUNDLE_WITHOUT'] = 'test'
  # ENV['BUNDLE_PATH'] = install_dir

  bundle_exe = File.join("#{install_dir}/ruby/#{ruby_gem_dir}", 'bin', 'bundle')
  bundle_cmd = "ruby #{bundle_exe} _#{bundler_version}_"
  raise 'Required bundle executable not found' unless File.exist?(bundle_exe)

  if File.exist?('Gemfile.lock')
    puts 'Removing Gemfile.lock'
    FileUtils.rm('Gemfile.lock')
  end

  puts '=' * 33 + ' bundle config ' + '=' * 32
  system_call("#{bundle_cmd} config")
  puts '=' * 80

  puts '=' * 16 + ' precaching packages and building them manually ' + '=' * 16
  # Shenigans onto shenanigans: Bundler, when you specify :git or :path
  # actually installs in #{install_dir}/ruby/#{ruby_gem_dir} under the
  # bundler/gems folder, and not under the gems/ one
  # and that's causing a lot of troubles for openstudio to find them
  # So here we:
  #   * Download everything into the vendor/cache folder
  #   * Find everything that's a directory, not a .gem file, go in there, build
  #   it and move it back up
  #   * Then we bundle install --local to use that vendor/cache,
  #   and all is _well_
  system_call("#{bundle_cmd} cache --no-install") # No need for "--all" conanfile sets BUNDLE_CACHE_ALL, and specifying it prints an annoying warning

  Dir.glob('vendor/cache/*').select { |x| File.directory?(x) }.each do |d|
    gemspec = nil
    gemspec = 'jaro_winkler.gemspec' if d.include?('jaro_winkler')

    if d.include?('jaro_winkler')
      puts "Patching jaro_winkler in #{d}"
      jaro_c_path = File.join(d, 'ext', 'jaro_winkler', 'jaro.c')
      if File.exist?(jaro_c_path)
        content = File.read(jaro_c_path)

        # Replace VLA with calloc
        if content.gsub!(/char short_codes_flag\[len1\];/,
                         'char *short_codes_flag = (char *)calloc(len1, sizeof(char));')
          puts 'Patched short_codes_flag declaration'
        else
          puts 'Failed to patch short_codes_flag declaration'
        end

        if content.gsub!(/char long_codes_flag\[len2\];/, 'char *long_codes_flag = (char *)calloc(len2, sizeof(char));')
          puts 'Patched long_codes_flag declaration'
        else
          puts 'Failed to patch long_codes_flag declaration'
        end

        # Remove memset as calloc initializes to 0
        content.gsub!(/memset\(short_codes_flag, 0, len1\);/, '// memset(short_codes_flag, 0, len1);')
        content.gsub!(/memset\(long_codes_flag, 0, len2\);/, '// memset(long_codes_flag, 0, len2);')

        # Add free before returns
        # There are two returns after allocation

        # 1. if (!match_count) return 0.0;
        if content.gsub!(/if \(!match_count\)\s+return 0.0;/,
                         "if (!match_count) {\n    free(short_codes_flag);\n    free(long_codes_flag);\n    return 0.0;\n  }")
          puts 'Patched return 0.0'
        else
          puts 'Failed to patch return 0.0'
        end

        # 2. Final return
        # return (m / len1 + m / len2 + (m - t) / m) / 3;
        if content.gsub!(%r{return \(m / len1 \+ m / len2 \+ \(m - t\) / m\) / 3;},
                         "free(short_codes_flag);\n  free(long_codes_flag);\n  return (m / len1 + m / len2 + (m - t) / m) / 3;")
          puts 'Patched final return'
        else
          puts 'Failed to patch final return'
        end

        File.write(jaro_c_path, content)
      else
        puts "Could not find jaro.c at #{jaro_c_path}"
      end
    end

    Dir.chdir(d) do
      system("gem build #{gemspec}")
      Dir.glob('*.gem').each { |x| FileUtils.move(x, '..') }
    end
    FileUtils.rm_rf(d)
  end

  FileUtils.rm_rf("#{install_dir}/ruby/#{ruby_gem_dir}/bundler")
  puts '=' * 80

  puts '=' * 26 + ' installing from local cache ' + '=' * 25
  system_call("#{bundle_cmd} install --local --no-cache", true)
  puts '=' * 80

  lib_ext = RbConfig::CONFIG['LIBEXT']
  libs = Dir.glob("./openstudio-gems/**/*.#{lib_ext}")
  lib_names_woext = Set.new(libs.map { |lib| File.basename(lib, File.extname(lib)) })
  expected = Set.new(%w[jaro_winkler_ext libll liboga msgpack byebug generator parser prism cparse]) # unf_ext: disabled with json_schemer
  unless is_unix
    expected.add('sqlite3_native') # TODO: I don't understand why we don't have it yet...
  end
  if lib_names_woext != expected
    puts "Missing expected extensions: #{expected - lib_names_woext}"
    puts "Extra unexpected extensions: #{lib_names_woext - expected}"
    raise 'Unexpected results with native extensions'
  end

  FileUtils.rm_f("#{install_dir}/Gemfile.lock")
  system_call("#{bundle_cmd} lock --add_platform ruby", true) # TODO: need --local ?

  # DLM: don't remove system platforms, that creates problems when running bundle on the command line
  # these will be removed later
  platforms_to_remove = %w[mri mingw x64_mingw x64-mingw32 rbx jruby mswin mswin64]
  # platforms_to_remove.each do |platform|
  #  system_call("#{bundle_exe} _#{bundler_version}_ lock --remove_platform #{platform}")
  # end

  FileUtils.rm_rf("#{install_dir}/ruby/#{ruby_gem_dir}/cache")

  # Remove .git, .github, .gitiginore
  Dir.glob("#{install_dir}/ruby/#{ruby_gem_dir}/**/.git*").each do |f|
    FileUtils.rm_rf(f)
  end

  Dir.glob("#{install_dir}/ruby/#{ruby_gem_dir}/gems/*/spec")

  folders_to_remove = %w[doc docs test spec specs]
  folders_to_remove.each do |folder|
    Dir.glob("#{install_dir}/ruby/#{ruby_gem_dir}/gems/*/#{folder}/").each { |f| FileUtils.rm_rf(f) }
    Dir.glob("#{install_dir}/ruby/#{ruby_gem_dir}/bundler/gems/*//#{folder}/").each { |f| FileUtils.rm_rf(f) }
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
    FileUtils.rm_f(f) if /CAN_/.match(f)
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
      gemfile_lock += line unless skip
    end
  end
  File.open("#{install_dir}/Gemfile.lock", 'w') do |file|
    file.puts(gemfile_lock)
    # make sure data is written to the disk one way or the other
    begin
      file.fsync
    rescue StandardError
      file.flush
    end
  end

  date = if ENV['DATE'].nil?
           DateTime.now.strftime('%Y%m%d')
         else
           ENV['DATE']
         end
  # TODO: at some point we should provide a proper cmake gems-config.cmake
  new_file_name = "openstudio3-gems-#{date}-#{platform_prefix}-#{expected_ruby_version}.tar.gz"
  File.open("#{install_dir}/version.txt", 'w') do |f|
    f.puts new_file_name
  end

  # Globbing through 6000 files in cmake everytime we rerun configure takes way
  # too much time (the worst being windows), so prepare a list for embedding
  extensions_to_glob = %w[rb data erb js css gif png html idf osm epw ddy stat
                          csv json gemspec gz yml]
  puts "Globbing for #{extensions_to_glob} to add it to export-extensions.cmake"
  measure_tester_rubocop_yml = Dir.glob('**/openstudio_measure_tester*/.rubocop.yml', base: install_dir)
  unless measure_tester_rubocop_yml.size == 1
    raise "openstudio_measure_tester .rubocop.yml not found: '#{measure_tester_rubocop_yml}'"
  end

  measure_tester_rubocop_yml = measure_tester_rubocop_yml.first
  # gemEmbbedPaths = Dir.glob("**/*.{#{extensions_to_glob.join(",")}}", base: install_dir)
  # gemEmbbedPaths << measure_tester_rubocop_yml
  gemEmbbedPaths = Dir.glob("**/*.{#{extensions_to_glob.join(',')}}", File::FNM_DOTMATCH, base: install_dir)
  unless gemEmbbedPaths.include?(measure_tester_rubocop_yml)
    raise 'Missing openstudio_measure_tester .rubocop.yml which is needed'
  end

  gemEmbbedPaths.reject! do |x|
    File.basename(x) == '.travis.yml' || (File.basename(x).include?('.rubocop') && !x.include?('openstudio_measure_tester'))
  end
  unless gemEmbbedPaths.include?(measure_tester_rubocop_yml)
    raise 'Missing openstudio_measure_tester .rubocop.yml which is needed'
  end

  puts "Found #{gemEmbbedPaths.size} files"
  # gemEmbbedPaths = all_files.map{|f| (Pathname.new(f).relative_path_from install_dir).to_s }
  gemFiles = gemEmbbedPaths.map { |f| "\"${OPENSTUDIO_GEMS_DIR}/#{f}\"" }
  exports_file_name = "#{install_dir}/export-extensions.cmake"
  File.open(exports_file_name, 'a') do |f|
    f.puts 'set(gemFiles'
    gemFiles.each { |x| f.puts "  #{x}" }
    f.puts ')'
    f.puts
    f.puts 'set(gemEmbeddedPaths'
    gemEmbbedPaths.each { |x| f.puts "  #{x}" }
    f.puts ')'
  end

  # TODO: no longer chdir'ing, so this shouldn't be necessary
  puts "Current directory: #{Dir.pwd}"
  Dir.chdir("#{install_dir}/..")

  FileUtils.rm_f(new_file_name) if File.exist?(new_file_name)

  system_call("\"#{tar_exe}\" -zcf \"#{new_file_name}\" \"openstudio-gems\"")

  puts
  puts "You need to manually upload #{new_file_name} to S3:openstudio-resources/dependencies/"
  puts "Also, you will need to update OpenStudio/CMakeLists.txt with the new file name and the md5 hash (call `md5 #{new_file_name}` or `md5sum #{new_file_name}` to get hash)"
  puts
  cmd = nil
  cmd = if platform_prefix == 'Windows'
          "certutil -hashfile \"#{new_file_name}\" MD5"
        else
          "md5sum \"#{new_file_name}\""
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

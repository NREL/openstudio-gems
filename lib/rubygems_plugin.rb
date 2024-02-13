require 'tmpdir'
require 'tempfile'

class StaticExtensionPlugin

  def initialize
    puts 'Init StaticExtensionPlugin'

    @dir =  __dir__
    @install_dir = File.expand_path(@dir + "/../openstudio-gems")
    puts "@dir=#{@dir}"
    @exports_file_name = @dir + "/../openstudio-gems/export-extensions.cmake"
    @ext_init_file_name = @dir + "/../openstudio-gems/ext-init.hpp"

    create_exports_file
    create_init_file

    post_install
  end

  def self.get_relative_path(path)
    path[0..Dir.pwd.length-1] = '.' if path.start_with?(Dir.pwd)
    path
  end

  def self.make_static(dest_path, results)
    unless File.exist? "#{File.join(dest_path, 'Makefile')}" then
      raise Gem::InstallError, 'Makefile not found'
    end

    # try to find make program from Ruby configure arguments first
    # try to find make program from Ruby configure arguments first
    RbConfig::CONFIG["configure_args"] =~ /with-make-prog\=(\w+)/
    make_program_name = ENV["MAKE"] || ENV["make"] || $1
    make_program_name ||= RUBY_PLATFORM.include?("mswin") ? "nmake" : "make"
    make_program = Shellwords.split(make_program_name)

    # The installation of the bundled gems is failed when DESTDIR is empty in mswin platform.
    destdir = /\bnmake/i !~ make_program_name || ENV["DESTDIR"] && ENV["DESTDIR"] != "" ? format("DESTDIR=%s", ENV["DESTDIR"]) : ""
    env = [destdir]

    ['static'].each do |target|
      # Pass DESTDIR via command line to override what's in MAKEFLAGS
      cmd = [
        *make_program,
        *env,
        target
      ].reject(&:empty?)
      begin
        Gem::Ext::Builder.run(cmd, results, "make #{target}".rstrip, dest_path)
      rescue Gem::InstallError
        raise unless target == 'clean' # ignore clean failure
      ensure
        puts "make results:"
        puts results.join("\n").strip
      end
    end
  end

  def create_exports_file
    f = File.new(@exports_file_name, "w")
    f.close
  end

  def create_init_file
    f = File.new(@ext_init_file_name, "w")
    f.close
  end

  def post_install
    Gem.post_install do |installer|
      installer.spec.extensions.each do |extension|
        puts "Build static extension: #{extension}"

        extension_dir = File.expand_path File.join installer.spec.full_gem_path, File.dirname(extension)
        extname = Pathname.new(extension).parent.basename

        # Work-around for native gems with non-standard library names
        # Glob `#{extname}.#{RbConfig::MAKEFILE_CONFIG['LIBEXT']}` won't work
        # because when this is set, the file doesn't exist yet.
        extconf_args = []

        if extension_dir.to_s.include? "oga"
          extname = "liboga"
        elsif extension_dir.to_s.include? "ruby-ll"
          extname = "libll"
        elsif extname.to_s == "jaro_winkler"
          extname = "jaro_winkler_ext"
        elsif extname.to_s == "sqlite3"
          extname = "sqlite3_native"
          extconf_args = ["--enable-system-libraries", "--with-pkg-config=pkgconf"]
        elsif extname.to_s == "oga"
          extname = "liboga"
        end

        puts "extension=#{extension}, extname=#{extname}"
        puts "installer.spec.full_gem_path=#{installer.spec.full_gem_path}"
        puts "extension_dir=#{extension_dir}, @install_dir=#{@install_dir}"
        lib_path = "#{extension_dir.sub(@install_dir, "")}/#{extname}.#{RbConfig::MAKEFILE_CONFIG['LIBEXT']}"
        target_name = "ruby-ext-#{extname}"

        # enable Gem.configure.really_verbose
        # Gem.configuration.verbose = 10

        tmp_dest = Dir.mktmpdir(".gem.", ".")
        puts "tmp_dest=#{tmp_dest}"
        puts "extension_dir=#{extension_dir}"

        siteconf_path = "#{extension_dir}/siteconf.rb"
        File.open(siteconf_path, "w") do |siteconf|
        # Tempfile.open %w"siteconf .rb", extension_dir do |siteconf|
          siteconf.puts "require 'mkmf'"
          siteconf.puts "$static = true"
          # This is missing fPIC
          if extname == 'unf_ext' and RbConfig::CONFIG['host_os'] =~ /linux/
            siteconf.puts "$CPPFLAGS << ' ' << '-fPIC'"
          end
          siteconf.puts "require 'rbconfig'"
          siteconf.puts "dest_path = #{File.absolute_path(tmp_dest).dump}"
          %w[sitearchdir sitelibdir].each do |dir|
            siteconf.puts "RbConfig::MAKEFILE_CONFIG['#{dir}'] = dest_path"
            siteconf.puts "RbConfig::CONFIG['#{dir}'] = dest_path"
          end
        end

        cmd = [Gem.ruby, "-r", "./siteconf.rb", File.basename(extension), *extconf_args]
        puts "cmd=#{cmd}"

        results = []
        begin
          Gem::Ext::Builder.run cmd, results, "Building #{extension}", extension_dir
        ensure
          if File.exist? File.join(extension_dir, 'mkmf.log')
            unless $?.nil? || $?.success? then
              results << "To see why this extension failed to compile, please check" \
                " the mkmf.log which can be found here:\n"
              results << "  " + File.join(tmp_dest, 'mkmf.log') + "\n"
            end
            puts "results:"
            puts results.join("\n").strip
            FileUtils.mv File.join(extension_dir, 'mkmf.log'), tmp_dest
          end
          File.delete(siteconf_path) if File.exist? siteconf_path
        end

        StaticExtensionPlugin.make_static extension_dir, results

        File.open(@ext_init_file_name, "a") do |f|
          f.puts "extern \"C\" {"
          f.puts "  void Init_#{extname}(void);"
          f.puts "}"
          f.puts
          f.puts "namespace embedded_help {"
          f.puts "  inline void init_#{extname}() {"
          f.puts "    Init_#{extname}();"
          f.puts "  }"
          f.puts "}"
          f.puts
        end

        File.open(@exports_file_name, "a") do |f|
          f.puts "add_library(#{target_name} STATIC IMPORTED)"
          f.puts "set_target_properties(#{target_name} PROPERTIES IMPORTED_LOCATION \"${OPENSTUDIO_GEMS_DIR}#{lib_path}\")"
          f.puts "list(APPEND ruby_extension_libs #{target_name})"
          f.puts
        end
      end
    end
  end

end

StaticExtensionPlugin.new


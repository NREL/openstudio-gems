
class StaticExtensionPlugin

  def initialize
    puts 'Init StaticExtensionPlugin'

    @dir =  __dir__
    @install_dir = File.expand_path(@dir + "/../openstudio-gems")
    @exports_file_name = @dir + "/../openstudio-gems/export-extensions.cmake"
    @init_file_name = @dir + "/../openstudio-gems/init-extensions.cpp"

    create_exports_file
    create_init_file

    post_install
  end

  def self.get_relative_path(path)
    path[0..Dir.pwd.length-1] = '.' if path.start_with?(Dir.pwd)
    path
  end
  
  def self.make_static(dest_path, results)
    unless File.exist? 'Makefile' then
      raise Gem::InstallError, 'Makefile not found'
    end
  
    # try to find make program from Ruby configure arguments first
    RbConfig::CONFIG['configure_args'] =~ /with-make-prog\=(\w+)/
    make_program = ENV['MAKE'] || ENV['make'] || $1
    unless make_program then
      make_program = (/mswin/ =~ RUBY_PLATFORM) ? 'nmake' : 'make'
    end
  
    destdir = '"DESTDIR=%s"' % ENV['DESTDIR'] if RUBY_VERSION > '2.0'
  
    ['static'].each do |target|
      # Pass DESTDIR via command line to override what's in MAKEFLAGS
      cmd = [
        make_program,
        destdir,
        target
      ].join(' ').rstrip
      begin
        Gem::Ext::Builder.run(cmd, results, "make #{target}".rstrip)
      rescue Gem::InstallError
        raise unless target == 'clean' # ignore clean failure
      end
    end
  end
  
  def create_exports_file
    f = File.new(@exports_file_name, "w")
    f.close
  end
  
  def create_init_file
    f = File.new(@init_file_name, "w")
    f.close
  end

  def post_install
    Gem.post_install do |installer|
      installer.spec.extensions.each do |extension|
        puts "Build static extension: #{extension}"

        extension_dir = File.expand_path File.join installer.spec.full_gem_path, File.dirname(extension)
        extname = Pathname.new(extension).parent.basename
        lib_path = "#{extension_dir.sub(@install_dir, "")}/#{extname}.#{RbConfig::MAKEFILE_CONFIG['LIBEXT']}"
        target_name = "ruby-ext-#{extname}"
    
        tmp_dest = Dir.mktmpdir(".gem.", ".")
    
        Dir.chdir extension_dir do
          Tempfile.open %w"siteconf .rb", "." do |siteconf|
            siteconf.puts "require 'mkmf'"
            siteconf.puts "$static = true"
            siteconf.puts "require 'rbconfig'"
            siteconf.puts "dest_path = #{tmp_dest.dump}"
            %w[sitearchdir sitelibdir].each do |dir|
              siteconf.puts "RbConfig::MAKEFILE_CONFIG['#{dir}'] = dest_path"
              siteconf.puts "RbConfig::CONFIG['#{dir}'] = dest_path"
            end
    
            siteconf.close
    
            cmd = [Gem.ruby, "-r", StaticExtensionPlugin.get_relative_path(siteconf.path), File.basename(extension)].join ' '
            results = []
    
            begin
              Gem::Ext::Builder.run cmd, results
            ensure
              if File.exist? 'mkmf.log'
                unless $?.success? then
                  results << "To see why this extension failed to compile, please check" \
                    " the mkmf.log which can be found here:\n"
                  results << "  " + File.join(dest_path, 'mkmf.log') + "\n"
                end
                FileUtils.mv 'mkmf.log', dest_path
              end
              siteconf.unlink
            end
    
            StaticExtensionPlugin.make_static extension_dir, results
    
          end
        end

        File.open(@init_file_name, "a") do |f|
          f.puts "init_#{extname}()"
          f.puts "rb_provides(\"#{extname}\")"
          f.puts "rb_provides(\"#{extname}.so\")"
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


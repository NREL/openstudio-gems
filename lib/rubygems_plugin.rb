
def get_relative_path(path)
  path[0..Dir.pwd.length-1] = '.' if path.start_with?(Dir.pwd)
  path
end

def make_static(dest_path, results)
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

Gem.post_install do |installer|
  installer.spec.extensions.each do |extension|
    puts "Build static extension: #{extension}"

    tmp_dest = Dir.mktmpdir(".gem.", ".")

    extension_dir =
      File.expand_path File.join installer.spec.full_gem_path, File.dirname(extension)

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

        cmd = [Gem.ruby, "-r", get_relative_path(siteconf.path), File.basename(extension)].join ' '
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

        make_static extension_dir, results

      end
    end
  end
end

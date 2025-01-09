# -*- coding: utf-8 -*-
require 'rake/testtask'
require 'rake/clean'
require 'rubygems/package_task'

require_relative 'lib/versadok/version'

Rake::TestTask.new do |t|
  t.libs << 'test'
  t.test_files = FileList['test/**/*.rb']
  t.verbose = false
  t.warning = true
end

namespace :dev do
  CLOBBER << "VERSION"
  file 'VERSION' do
    puts "Generating VERSION file"
    File.open('VERSION', 'w+') {|file| file.write(VersaDok::VERSION + "\n") }
  end

  CLOBBER << 'CONTRIBUTERS'
  file 'CONTRIBUTERS' do
    puts "Generating CONTRIBUTERS file"
    `echo "  Count Name" > CONTRIBUTERS`
    `echo "======= ====" >> CONTRIBUTERS`
    `git log | grep ^Author: | sed 's/^Author: //' | sort | uniq -c | sort -nr >> CONTRIBUTERS`
  end

  spec = eval(File.read('versadok.gemspec'), binding, 'versadok.gemspec')
  Gem::PackageTask.new(spec)

  desc "Upload the release to Rubygems"
  task publish_files: [:package] do
    sh "gem push pkg/versadok-#{VersaDok::VERSION}.gem"
    puts 'done'
  end

  task :test_all do
    versions = `rbenv versions --bare | grep -i ^3.`.split("\n")
    versions.each do |version|
      sh "eval \"$(rbenv init -)\"; rbenv shell #{version} && ruby -v && rake test"
    end
    puts "Looks okay? (enter to continue, Ctrl-c to abort)"
    $stdin.gets
  end

  desc 'Release VersaDok version ' + VersaDok::VERSION
  task release: [:clobber, :test_all, :package, :publish_files]

  CODING_LINE = "# -*- encoding: utf-8; frozen_string_literal: true -*-\n"

  desc "Insert/Update copyright notice"
  task :update_copyright do
    license = File.readlines(File.join(__dir__, 'LICENSE')).map do |l|
      l.strip.empty? ? "#\n" : "# #{l}"
    end.join
    statement = CODING_LINE + "#\n#--\n# This file is part of VersaDok.\n#\n" + license + "#++\n"
    inserted = false
    Dir["lib/**/*.rb"].each do |file|
      unless File.read(file).start_with?(statement)
        inserted = true
        puts "Updating file #{file}"
        old = File.read(file)
        unless old.gsub!(/\A#{Regexp.escape(CODING_LINE)}#\n#--.*?\n#\+\+\n/m, statement)
          old.gsub!(/\A(#{Regexp.escape(CODING_LINE)})?/, statement)
        end
        File.write(file, old)
      end
    end
    puts "Look through the above mentioned files and correct all problems" if inserted
  end
end

task clobber: 'dev:clobber'
task default: 'test'

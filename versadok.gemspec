require_relative 'lib/versadok/version'

PKG_FILES = Dir.glob([
                       'bin/*',
                       'lib/**/*.rb',
                       'data/**/*',
                       'test/**/*',
                       'Rakefile',
                       'LICENSE',
                       'VERSION',
                       'CONTRIBUTERS',
                       'CHANGELOG.md'
                     ])

Gem::Specification.new do |s|
  s.name = 'versadok'
  s.version = VersaDok::VERSION
  s.summary = "VersaDok - Versatile document creation markup and library"
  s.description = 'VersaDok is both a lightweight markup language for creating ' \
                  'documents as well as a library to actually convert such documents'
  s.licenses = ['MIT']

  s.files = PKG_FILES

  s.require_path = 'lib'
  s.executables = ['versadok']
  s.add_dependency('strscan', '>= 3.1.2')
  s.required_ruby_version = '>= 3.0'

  s.author = 'Thomas Leitner'
  s.email = 't_leitner@gmx.at'
  s.homepage = "https://versadok.gettalong.org"
end

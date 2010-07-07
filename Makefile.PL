
sub githubmeta  { warn 'You need Module::Install::GithubMeta installed' }
sub extra_tests { warn 'You need Module::Install::ExtraTests installed' }

use inc::Module::Install;

githubmeta;

name     'MooseX-AutoDestruct';
all_from 'lib/MooseX/AutoDestruct.pm';
author   q{Chris Weyl <cweyl@alumni.drew.edu>};
license  'lgpl';

readme_from 'lib/MooseX/AutoDestruct.pm';
readme_markdown_from 'lib/MooseX/AutoDestruct.pm';

requires 'namespace::autoclean' => '0.09';
requires 'Moose' => '0.94';

test_requires 'Test::More';
test_requires 'Test::Moose';

author_requires 'File::Find::Rule';
author_requires 'FindBin';
author_requires 'Module::ScanDeps';

no_index package => 'Moose::Meta::Attribute::Custom::Trait::AutoDestruct';

extra_tests;
auto_install;
auto_provides;
write_mymeta_json;

WriteAll;


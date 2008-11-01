use inc::Module::Install;
include 'Module::AutoInstall';

name 'Vim-Complete';
all_from 'lib/Vim/Complete.pm';
perl_version '5.006';

requires 'Class::Accessor::Complex';
requires 'Getopt::Attribute';
requires 'PPI';

recommends 'Test::Pod';
recommends 'Test::Pod::Coverage';

test_requires 'Test::Differences';
test_requires 'Test::More' => '0.70';
test_requires 'Test::Compile';

install_script glob('bin/*');

auto_install;
auto_include;
WriteAll;

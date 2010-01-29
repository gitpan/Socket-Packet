use strict;
use warnings;

use Module::Build;

eval { require ExtUtils::CChecker; 1 } or
   die "OS unsupported - missing ExtUtils::CChecker";

ExtUtils::CChecker->new->assert_compile_run(
   diag => "no PF_PACKET",
   source => <<'EOF' );
#include <stdio.h>
#include <sys/socket.h>
int main(int argc, char *argv[]) {
  printf("PF_PACKET is %d\n", PF_PACKET);
  return 0;
}
EOF

my $build = Module::Build->new(
   module_name => 'Socket::Packet',
   requires => {
   },
   configure_requires => {
      'ExtUtils::CChecker' => 0,
      'Module::Build' => 0,
      'Module::Build::Compat' => 0,
   },
   build_requires => {
      'ExtUtils::CChecker' => 0,
      'IO::Socket::INET' => 0,
      'Module::Build' => 0,
      'Module::Build::Compat' => 0,
      'Test::More' => 0,
   },
   license => 'perl',
   create_makefile_pl => 'small',
   create_license => 1,
   create_readme  => 1,
);

$build->create_build_script;

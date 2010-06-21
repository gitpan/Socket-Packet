use strict;
use warnings;

use Module::Build;

eval "use ExtUtils::CChecker 0.03; 1" or
   die "OS unsupported - missing ExtUtils::CChecker ($@)";

my $cc = ExtUtils::CChecker->new;

$cc->assert_compile_run(
   diag => "no PF_PACKET",
   source => <<'EOF' );
#include <sys/socket.h>
int family = PF_PACKET;
int main(int argc, char *argv[]) {
  return 0;
}
EOF

# Some userland headers are sufficiently old that they don't have TPACKET_V2
# or the tpacket2_hdr structure. If this is the case we have little choice but
# to cheat a little and try to use the kernel ones instead.
chomp( my $uname_r = `uname -r` );

$cc->find_include_dirs_for(
   diag => "no PACKET_STATISTICS",
   dirs => [
      [],
      [ "/lib/modules/$uname_r/build/include" ],
   ],
   source => <<'EOF' );
#include <linux/if_packet.h>
int origdev = PACKET_STATISTICS;
struct tpacket_stats stats;
int main(int argc, char *argv[]) {
  return 0;
}
EOF

$cc->try_compile_run(
   define => "HAVE_ORIGDEV",
   source => <<'EOF' );
#include <linux/if_packet.h>
int origdev = PACKET_ORIGDEV;
int main(int argc, char *argv[]) {
  return 0;
}
EOF

$cc->try_compile_run(
   define => "HAVE_TPACKET",
   source => <<'EOF' );
#include <linux/if_packet.h>
struct tpacket_hdr hdr;
int main(int argc, char *argv[]) {
  return 0;
}
EOF

$cc->try_compile_run(
   define => "HAVE_TPACKET2",
   source => <<'EOF' );
#include <linux/if_packet.h>
int pkttype = TPACKET_V2;
struct tpacket2_hdr hdr;
int main(int argc, char *argv[]) {
  return 0;
}
EOF

my $build = $cc->new_module_build(
   module_name => 'Socket::Packet',
   requires => {
   },
   configure_requires => {
      'ExtUtils::CChecker' => '0.03',
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

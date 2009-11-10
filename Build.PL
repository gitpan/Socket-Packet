use strict;
use warnings;

use Module::Build;

eval { require ExtUtils::CBuilder; 1 } or
   die "OS unsupported - missing ExtUtils::CBuilder";

# See if we can compile and run a program that prints the value of PF_PACKET
print "Detecting if the OS can support PF_PACKET...\n";

# Stolen from Socket-GetAddrInfo/Build.PL
sub try_compile_run
{
   my ( $cbuilder, $name, $source ) = @_;

   my $test_source = "test-$name.c";

   open( my $test_source_fh, "> $test_source" ) or die "Cannot write $test_source - $!";

   print $test_source_fh $source;

   close $test_source_fh;

   my $test_obj = eval { $cbuilder->compile( source => $test_source ) };

   unlink $test_source;

   if( not defined $test_obj ) {
      print "\nFailed to compile $test_source\n";
      return 0;
   }

   print "Compiled $test_source to $test_obj\n\n";

   my $test_exe = eval { $cbuilder->link_executable( objects => $test_obj ) };
   END { defined $test_exe and -f $test_exe and unlink $test_exe; }

   unlink $test_obj;

   if( not defined $test_exe ) {
      print "\nFailed to link $test_obj to an executable\n";
      return 0;
   }

   print "Linked $test_obj to $test_exe\n\n";

   if( system( "./$test_exe" ) != 0 ) {
      print "\nFailed to run $test_exe\n";
      unlink $test_exe;
      return 0;
   }

   unlink $test_exe;

   return 1;
}

my $cbuilder = ExtUtils::CBuilder->new;
die "OS unsupported - no PF_PACKET" unless try_compile_run $cbuilder, "packet", <<'EOF';
#include <stdio.h>
#include <sys/socket.h>
int main(int argc, char *argv[]) {
  printf("PF_PACKET is %d\n", PF_PACKET);
  return 0;
}
EOF

my $build = Module::Build->new
  (
   module_name => 'Socket::Packet',
   requires => {
               },
   configure_requires => {
                 'Module::Build' => 0,
                 'Module::Build::Compat' => 0,
   },
   build_requires => {
                 'ExtUtils::CBuilder' => 0,
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

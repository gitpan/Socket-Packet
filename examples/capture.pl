#!/usr/bin/perl

use strict;
use warnings;

use Socket qw( SOCK_DGRAM );
use Socket::Packet qw(
   PF_PACKET
   ETH_P_ALL
   pack_sockaddr_ll unpack_sockaddr_ll
   PACKET_OUTGOING
);

socket( my $sock, PF_PACKET, SOCK_DGRAM, 0 ) or die "Cannot socket() - $!\n";

bind( $sock, pack_sockaddr_ll( ETH_P_ALL, 0, 0, 0, "" ) ) or die "Cannot bind() - $!\n";

while( my $addr = recv( $sock, my $packet, 8192, 0 ) ) {
   my ( $proto, $ifindex, $hatype, $pkttype, $addr ) = unpack_sockaddr_ll( $addr );

   # Reformat nicely for printing
   $addr = join( ":", map sprintf("%02x", ord $_), split //, $addr );

   if( $pkttype == PACKET_OUTGOING ) {
      print "Sent a packet to $addr";
   }
   else {
      print "Received a packet from $addr";
   }

   printf " of protocol %04x on interface %d:\n", $proto, $ifindex;

   printf "  %v02x\n", $1 while $packet =~ m/(.{1,16})/g;
}

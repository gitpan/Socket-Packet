#  You may distribute under the terms of either the GNU General Public License
#  or the Artistic License (the same terms as Perl itself)
#
#  (C) Paul Evans, 2009 -- leonerd@leonerd.org.uk

package Socket::Packet;

use strict;
use warnings;

use Carp;

use base qw( Exporter );
use base qw( DynaLoader );

our $VERSION = "0.01";

our @EXPORT_OK = qw(
   pack_sockaddr_ll
   unpack_sockaddr_ll
);

__PACKAGE__->DynaLoader::bootstrap( $VERSION );

=head1 NAME

C<Socket::Packet> - interface to Linux's C<PF_PACKET> socket family

=head1 SYNOPSIS

 use Socket qw( SOCK_DGRAM );
 use Socket::Packet qw(
    PF_PACKET
    ETH_P_ALL
    pack_sockaddr_ll unpack_sockaddr_ll
 );
 
 socket( my $sock, PF_PACKET, SOCK_DGRAM, 0 )
    or die "Cannot socket() - $!\n";
 
 bind( $sock, pack_sockaddr_ll( ETH_P_ALL, 0, 0, 0, "" ) )
    or die "Cannot bind() - $!\n";
 
 while( my $addr = recv( $sock, my $packet, 8192, 0 ) ) {
    my ( $proto, $ifindex, $hatype, $pkttype, $addr )
       = unpack_sockaddr_ll( $addr );

    ...
 }

=head1 DESCRIPTION

To quote C<packet(7)>:

 Packet sockets are used to receive or send raw packets at the device driver
 (OSI Layer 2) level. They allow the user to implement protocol modules in
 user space on top of the physical layer.

Sockets in the C<PF_PACKET> family get direct link-level access to the
underlying hardware (i.e. Ethernet or similar). They are usually used to
implement packet capturing, or sending of specially-constructed packets
or to implement protocols the underlying kernel does not recognise.

The use of C<PF_PACKET> sockets is usually restricted to privileged users
only.

=cut

=head1 CONSTANTS

The following constants are exported

=over 8

=item PF_PACKET

The packet family (for C<socket()> calls)

=item AF_PACKET

The address family

=item PACKET_HOST

This packet is inbound unicast for this host.

=item PACKET_BROADCAST

This packet is inbound broadcast.

=item PACKET_MULTICAST

This packet is inbound multicast.

=item PACKET_OTHERHOST

This packet is inbound unicast for another host.

=item PACKET_OUTGOING

This packet is outbound.

=item ETH_P_ALL

Pseudo-protocol number to capture all protocols.

=back

=cut

=head1 FUNCTIONS

The following pair of functions operate on C<AF_PACKET> address structures.
The meanings of the parameters are:

=over 8

=item protocol

An ethertype protocol number. When using an address with C<bind()>, the
constant C<ETH_P_ALL> can be used instead, to capture any protocol. The
C<pack_sockaddr_ll()> and C<unpack_sockaddr_ll()> functions byte-swap this
value to or from network endian order.

=item ifindex

The index number of the interface on which the packet was sent or received.
When using an address with C<bind()>, the value C<0> can be used instead, to
watch all interfaces.

=item hatype

The hardware ARP type of hardware address.

=item pkttype

The type of the packet; indicates if it was sent or received. Will be one of
the C<PACKET_*> values.

=item addr

The underlying hardware address, in the type given by C<hatype>.

=back

=cut

=head2 $a = pack_sockaddr_ll( $protocol, $ifindex, $hatype, $pkttype, $addr )

Returns a C<sockaddr_ll> structure with the fields packed into it.

=head2 ( $protocol, $ifindex, $hatype, $pkttype, $addr ) = unpack_sockaddr_ll( $a )

Takes a C<sockaddr_ll> structure and returns the unpacked fields from it.

=cut

# Keep perl happy; keep Britain tidy
1;

__END__

=head1 SEE ALSO

=over 4

=item *

C<packet(7)> - packet, AF_PACKET - packet interface on device level

=back

=head1 AUTHOR

Paul Evans <leonerd@leonerd.org.uk>

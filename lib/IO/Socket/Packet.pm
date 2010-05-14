#  You may distribute under the terms of either the GNU General Public License
#  or the Artistic License (the same terms as Perl itself)
#
#  (C) Paul Evans, 2009 -- leonerd@leonerd.org.uk

package IO::Socket::Packet;

use strict;
use warnings;
use base qw( IO::Socket );

our $VERSION = '0.05';

use Carp;

use Socket qw( AF_INET SOCK_STREAM SOCK_RAW );

use Socket::Packet qw( 
   AF_PACKET ETH_P_ALL
   pack_sockaddr_ll unpack_sockaddr_ll
   siocgstamp siocgstampns
   siocgifindex siocgifname
   recv_len
);

__PACKAGE__->register_domain( AF_PACKET );

=head1 NAME

C<IO::Socket::Packet> - Object interface to C<AF_PACKET> domain sockets

=head1 SYNOPSIS

 use IO::Socket::Packet;
 use Socket::Packet qw( unpack_sockaddr_ll );

 my $sock = IO::Socket::Packet->new( IfIndex => 0 );

 while( my ( $protocol, $ifindex, $hatype, $pkttype, $addr ) = 
    $sock->recv_unpack( my $packet, 8192, 0 ) ) {

    ...
 }

=head1 DESCRIPTION

This class provides an object interface to C<PF_PACKET> sockets on Linux. It
is built upon L<IO::Socket> and inherits all the methods defined by this base
class.

=cut

=head1 CONSTRUCTOR

=cut

=head2 $sock = IO::Socket::Packet->new( %args )

Creates a new C<IO::Socket::Packet> object. If any arguments are passed it
will be configured to contain a newly created socket handle, and be C<bind>ed
as required by the arguments. The recognised arguments are:

=over 8

=item Type => INT

The socktype to use; should be either C<SOCK_RAW> or C<SOCK_DGRAM>. It not
supplied a default of C<SOCK_RAW> will be used.

=item Protocol => INT

Ethernet protocol number to bind to. To capture all protocols, use the
C<ETH_P_ALL> constant (or omit this key, which implies that as a default).

=item IfIndex => INT

If supplied, binds the socket to the specified interface index. To bind to all
interfaces, use 0 (or omit this key, which implies that as a default).

=item IfName => STRING

If supplied, binds the socket to the interface with the specified name.

=back

=cut

sub configure
{
   my $self = shift;
   my ( $arg ) = @_;

   my $type = $arg->{Type} || SOCK_RAW;

   $self->socket( AF_PACKET, $type, 0 ) or return undef;

   # bind() arguments
   my ( $protocol, $ifindex );

   $protocol = $arg->{Protocol} if exists $arg->{Protocol};
   $ifindex  = $arg->{IfIndex}  if exists $arg->{IfIndex};

   if( !defined $ifindex and exists $arg->{IfName} ) {
      $ifindex = siocgifindex( $self, $arg->{IfName} );
      defined $ifindex or return undef;
   }

   $self->bind( pack_sockaddr_ll( 
         defined $protocol ? $protocol : ETH_P_ALL,
         $ifindex || 0,
         0, 0, '' ) ) or return undef;

   return $self;
}

=head1 METHODS

=cut

=head2 ( $protocol, $ifindex, $hatype, $pkttype, $addr ) = $sock->recv_unpack( $buffer, $size, $flags )

This method is a combination of C<recv> and C<unpack_sockaddr_ll>. If it
successfully receives a packet, it unpacks the address and returns the fields
from it. If it fails, it returns an empty list.

=cut

sub recv_unpack
{
   my $self = shift;
   my $addr = $self->recv( @_ ) or return;
   return unpack_sockaddr_ll( $addr );
}

=head2 $protocol = $sock->protocol

Returns the ethertype protocol the socket is bound to.

=cut

sub protocol
{
   my $self = shift;
   return (unpack_sockaddr_ll($self->sockname))[0];
}

=head2 $ifindex = $sock->ifindex

Returns the interface index the socket is bound to.

=cut

sub ifindex
{
   my $self = shift;
   return (unpack_sockaddr_ll($self->sockname))[1];
}

=head2 $ifname = $sock->ifname

Returns the name of the interface the socket is bound to.

=cut

sub ifname
{
   my $self = shift;
   return siocgifname( $self, $self->ifindex );
}

=head2 $hatype = $sock->hatype

Returns the hardware address type for the interface the socket is bound to.

=cut

sub hatype
{
   my $self = shift;
   return (unpack_sockaddr_ll($self->sockname))[2];
}

=head2 $time = $sock->timestamp

=head2 ( $sec, $usec ) = $sock->timestamp

Returns the timestamp of the last received packet on the socket (as obtained
by the C<SIOCGSTAMP> C<ioctl>). In scalar context, returns a single
floating-point value in UNIX epoch seconds. In list context, returns the
number of seconds, and the number of microseconds.

=cut

sub timestamp
{
   my $self = shift;
   return siocgstamp( $self );
}

=head2 $time = $sock->timestamp_nano

=head2 ( $sec, $nsec ) = $sock->timestamp_nano

Returns the nanosecond-precise timestamp of the last received packet on the
socket (as obtained by the C<SIOCGSTAMPNS> C<ioctl>). In scalar context,
returns a single floating-point value in UNIX epoch seconds. In list context,
returns the number of seconds, and the number of nanoseconds.

=cut

sub timestamp_nano
{
   my $self = shift;
   return siocgstampns( $self );
}

=head1 INTERFACE NAME UTILITIES

The following methods are utilities around C<siocgifindex> and C<siocgifname>.
If called on an object, they use the encapsulated socket. If called as class
methods, they will create a temporary socket to pass to the kernel, then close
it again.

=cut

=head2 $ifindex = $sock->ifname2index( $ifname )

=head2 $ifindex = IO::Socket::Packet->ifname2index( $ifname )

Returns the name for the given interface index, or C<undef> if it doesn't
exist.

=cut

sub ifname2index
{
   my $self = shift;
   my ( $ifname ) = @_;

   my $sock;
   if( ref $self ) {
      $sock = $self;
   }
   else {
      socket( $sock, AF_INET, SOCK_STREAM, 0 ) or
         croak "Cannot socket(AF_INET) - $!";
   }

   return siocgifindex( $sock, $ifname );
}

=head2 $ifname = $sock->ifindex2name( $ifindex )

=head2 $ifname = IO::Socket::Packet->ifindex2name( $ifindex )

Returns the index for the given interface name, or C<undef> if it doesn't
exist.

=cut

sub ifindex2name
{
   my $self = shift;
   my ( $ifindex ) = @_;

   my $sock;
   if( ref $self ) {
      $sock = $self;
   }
   else {
      socket( $sock, AF_INET, SOCK_STREAM, 0 ) or
         croak "Cannot socket(AF_INET) - $!";
   }

   return siocgifname( $sock, $ifindex );
}

=head2 ( $addr, $len ) = $sock->recv_len( $buffer, $maxlen, $flags )

Similar to Perl's C<recv> builtin, except it returns the packet length as an
explict return value. This may be useful if C<$flags> contains the
C<MSG_TRUNC> flag, obtaining the true length of the packet on the wire, even
if this is longer than the data written in the buffer.

=cut

# don't actually need to implement it; the imported symbol works fine

# Keep perl happy; keep Britain tidy
1;

__END__

=head1 SEE ALSO

=over 4

=item *

L<Socket::Packet> - interface to Linux's C<PF_PACKET> socket family

=back

=head1 AUTHOR

Paul Evans <leonerd@leonerd.org.uk>

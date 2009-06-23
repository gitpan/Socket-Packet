/*  You may distribute under the terms of either the GNU General Public License
 *  or the Artistic License (the same terms as Perl itself)
 *
 *  (C) Paul Evans, 2009 -- leonerd@leonerd.org.uk
 */

#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include <sys/socket.h>
#include <netpacket/packet.h>
#include <net/ethernet.h>

static void setup_constants(void)
{
  HV *stash;
  AV *export;

  stash = gv_stashpvn("Socket::Packet", 14, TRUE);
  export = get_av("Socket::Packet::EXPORT", TRUE);

#define DO_CONSTANT(c) \
  newCONSTSUB(stash, #c, newSViv(c)); \
  av_push(export, newSVpv(#c, 0));


  DO_CONSTANT(PF_PACKET)
  DO_CONSTANT(AF_PACKET)

  DO_CONSTANT(PACKET_HOST)
  DO_CONSTANT(PACKET_BROADCAST)
  DO_CONSTANT(PACKET_MULTICAST)
  DO_CONSTANT(PACKET_OTHERHOST)
  DO_CONSTANT(PACKET_OUTGOING)

  DO_CONSTANT(ETH_P_ALL)
}

MODULE = Socket::Packet    PACKAGE = Socket::Packet

BOOT:
  setup_constants();

void
pack_sockaddr_ll(protocol, ifindex, hatype, pkttype, addr)
    unsigned short  protocol
             int    ifindex
    unsigned short  hatype
    unsigned char   pkttype
    SV             *addr

  PREINIT:
    struct sockaddr_ll sll;
    char *addrbytes;
    STRLEN addrlen;

  PPCODE:
    if (DO_UTF8(addr) && !sv_utf8_downgrade(addr, 1))
      croak("Wide character in Socket::Packet::pack_sockaddr_ll");

    addrbytes = SvPVbyte(addr, addrlen);

    if(addrlen > 8)
      croak("addr too long; should be no more than 8 bytes, found %d", addrlen);

    sll.sll_family   = AF_PACKET;
    sll.sll_protocol = htons(protocol);
    sll.sll_ifindex  = ifindex;
    sll.sll_hatype   = hatype;
    sll.sll_pkttype  = pkttype;

    sll.sll_halen    = addrlen;
    memset(&sll.sll_addr, 0, 8);
    memcpy(&sll.sll_addr, addrbytes, addrlen);

    EXTEND(SP, 1);
    PUSHs(sv_2mortal(newSVpvn((char *)&sll, sizeof sll)));

void
unpack_sockaddr_ll(sa)
    SV * sa

  PREINIT:
    STRLEN sa_len;
    char *sa_bytes;
    struct sockaddr_ll sll;

  PPCODE:
    /* variable size of structure. Expect at least 12 bytes and no more than
     * 20, because there might be any from 0 to 8 address bytes */
    sa_bytes = SvPVbyte(sa, sa_len);
    if(sa_len < 12)
      croak("Socket address too small; found %d bytes, expected at least 12", sa_len);
    if(sa_len > 20)
      croak("Socket address too big; found %d bytes, expected at most 20", sa_len);

    memcpy(&sll, sa_bytes, sizeof sll);

    if(sa_len < 12 + sll.sll_halen)
      croak("Socket address too small; it did not provide enough bytes for sll_halen of %d", sll.sll_halen);

    if(sll.sll_family != AF_PACKET)
      croak("Bad address family for unpack_sockaddr_ll: got %d, expected %d", sll.sll_family, AF_PACKET);

    EXTEND(SP, 5);
    PUSHs(sv_2mortal(newSViv(ntohs(sll.sll_protocol))));
    PUSHs(sv_2mortal(newSViv(sll.sll_ifindex)));
    PUSHs(sv_2mortal(newSViv(sll.sll_hatype)));
    PUSHs(sv_2mortal(newSViv(sll.sll_pkttype)));
    PUSHs(sv_2mortal(newSVpvn((char *)sll.sll_addr, sll.sll_halen)));

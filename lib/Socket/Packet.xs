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
#include <linux/if.h>

/* Borrowed from IO/Sockatmark.xs */

#ifdef PerlIO
typedef PerlIO * InputStream;
#else
#define PERLIO_IS_STDIO 1
typedef FILE * InputStream;
#define PerlIO_fileno(f) fileno(f)
#endif

/* Lower and upper bounds of a valid struct sockaddr_ll */
static int sll_max;
static int sll_min;
/* Maximum number of address bytes in a struct sockaddr_ll */
static int sll_maxaddr;

static void setup_constants(void)
{
  sll_max = sizeof(struct sockaddr_ll);
  sll_maxaddr = sizeof(((struct sockaddr_ll*)NULL)->sll_addr);
  sll_min = sll_max - sll_maxaddr;

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

    if(addrlen > sll_maxaddr)
      croak("addr too long; should be no more than %d bytes, found %d", sll_maxaddr, addrlen);

    sll.sll_family   = AF_PACKET;
    sll.sll_protocol = htons(protocol);
    sll.sll_ifindex  = ifindex;
    sll.sll_hatype   = hatype;
    sll.sll_pkttype  = pkttype;

    sll.sll_halen    = addrlen;
    memset(&sll.sll_addr, 0, sll_maxaddr);
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
    /* variable size of structure, because of variable length of addr bytes */
    sa_bytes = SvPVbyte(sa, sa_len);
    if(sa_len < sll_min)
      croak("Socket address too small; found %d bytes, expected at least %d", sa_len, sll_min);
    if(sa_len > sll_max)
      croak("Socket address too big; found %d bytes, expected at most %d", sa_len, sll_max);

    memcpy(&sll, sa_bytes, sizeof sll);

    if(sa_len < sll_min + sll.sll_halen)
      croak("Socket address too small; it did not provide enough bytes for sll_halen of %d", sll.sll_halen);

    if(sll.sll_family != AF_PACKET)
      croak("Bad address family for unpack_sockaddr_ll: got %d, expected %d", sll.sll_family, AF_PACKET);

    EXTEND(SP, 5);
    PUSHs(sv_2mortal(newSViv(ntohs(sll.sll_protocol))));
    PUSHs(sv_2mortal(newSViv(sll.sll_ifindex)));
    PUSHs(sv_2mortal(newSViv(sll.sll_hatype)));
    PUSHs(sv_2mortal(newSViv(sll.sll_pkttype)));
    PUSHs(sv_2mortal(newSVpvn((char *)sll.sll_addr, sll.sll_halen)));

void
siocgstamp(sock)
  InputStream sock
  PROTOTYPE: $

  PREINIT:
    int fd;
    int result;
    struct timeval tv;

  PPCODE:
    fd = PerlIO_fileno(sock);
    if(ioctl(fd, SIOCGSTAMP, &tv) == -1) {
      if(GIMME_V == G_ARRAY)
        return;
      else
        XSRETURN_UNDEF;
    }

    if(GIMME_V == G_ARRAY) {
      EXTEND(SP, 2);
      PUSHs(sv_2mortal(newSViv(tv.tv_sec)));
      PUSHs(sv_2mortal(newSViv(tv.tv_usec)));
    }
    else {
      PUSHs(sv_2mortal(newSVnv((double)tv.tv_sec + (tv.tv_usec / 1000000.0))));
    }

void
siocgstampns(sock)
  InputStream sock
  PROTOTYPE: $

  PREINIT:
    int fd;
    int result;
    struct timespec ts;

  PPCODE:
#ifdef SIOCGSTAMPNS
    fd = PerlIO_fileno(sock);
    if(ioctl(fd, SIOCGSTAMPNS, &ts) == -1) {
      if(GIMME_V == G_ARRAY)
        return;
      else
        XSRETURN_UNDEF;
    }

    if(GIMME_V == G_ARRAY) {
      EXTEND(SP, 2);
      PUSHs(sv_2mortal(newSViv(ts.tv_sec)));
      PUSHs(sv_2mortal(newSViv(ts.tv_nsec)));
    }
    else {
      PUSHs(sv_2mortal(newSVnv((double)ts.tv_sec + (ts.tv_nsec / 1000000000.0))));
    }
#else
    croak("SIOCGSTAMPNS not implemented");
#endif

void
siocgifindex(sock, ifname)
  InputStream sock
  char *ifname
  PROTOTYPE: $$

  PREINIT:
    int fd;
    struct ifreq req;

  PPCODE:
#ifdef SIOCGIFINDEX
    fd = PerlIO_fileno(sock);
    strncpy(req.ifr_name, ifname, IFNAMSIZ);
    if(ioctl(fd, SIOCGIFINDEX, &req) == -1)
      XSRETURN_UNDEF;
    PUSHs(sv_2mortal(newSViv(req.ifr_ifindex)));
#else
    croak("SIOCGIFINDEX not implemented");
#endif

void
siocgifname(sock, ifindex)
  InputStream sock
  int ifindex
  PROTOTYPE: $$

  PREINIT:
    int fd;
    struct ifreq req;

  PPCODE:
#ifdef SIOCGIFNAME
    fd = PerlIO_fileno(sock);
    req.ifr_ifindex = ifindex;
    if(ioctl(fd, SIOCGIFNAME, &req) == -1)
      XSRETURN_UNDEF;
    PUSHs(sv_2mortal(newSVpv(req.ifr_name, 0)));
#else
    croak("SIOCGIFNAME not implemented");
#endif

void
recv_len(sock, buffer, maxlen, flags)
    InputStream sock
    SV *buffer
    int maxlen
    int flags

  PREINIT:
    int fd;
    char *bufferp;
    struct sockaddr_storage addr;
    socklen_t addrlen;
    int len;

  PPCODE:
    fd = PerlIO_fileno(sock);

    if(!SvOK(buffer))
      sv_setpvn(buffer, "", 0);

    bufferp = SvGROW(buffer, (STRLEN)(maxlen+1));

    addrlen = sizeof(addr);

    len = recvfrom(fd, bufferp, maxlen, flags, (struct sockaddr *)&addr, &addrlen);

    if(len < 0)
      XSRETURN_UNDEF;

    if(len > maxlen)
      SvCUR_set(buffer, maxlen);
    else
      SvCUR_set(buffer, len);

    *SvEND(buffer) = '\0';
    SvPOK_only(buffer);

    PUSHs(sv_2mortal(newSVpv((char *)&addr, addrlen)));
    PUSHs(sv_2mortal(newSViv(len)));

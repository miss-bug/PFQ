--    Copyright (c) 2011-14, Nicola Bonelli
--    All rights reserved.
--
--    Redistribution and use in source and binary forms, with or without
--    modification, are permitted provided that the following conditions are met:
--
--    * Redistributions of source code must retain the above copyright notice,
--      this list of conditions and the following disclaimer.
--    * Redistributions in binary form must reproduce the above copyright
--      notice, this list of conditions and the following disclaimer in the
--      documentation and/or other materials provided with the distribution.
--    * Neither the name of University of Pisa nor the names of its contributors
--      may be used to endorse or promote products derived from this software
--      without specific prior written permission.
--
--    THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
--    AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
--    IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
--    ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
--    LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
--    CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
--    SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
--    INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
--    CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
--    ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
--    POSSIBILITY OF SUCH DAMAGE.
--
--

{-# LANGUAGE ImpredicativeTypes #-}

module Network.PFq.Default
    (
        -- * Predicates
        -- | Collection of predicates used in conditional expressions.

        is_ip,
        is_udp,
        is_tcp,
        is_icmp,
        is_ip6,
        is_udp6,
        is_tcp6,
        is_icmp6,
        is_flow,
        is_l3_proto,
        is_l4_proto,

        is_frag,
        is_first_frag,
        is_more_frag,

        has_port,
        has_src_port,
        has_dst_port,

        has_addr,
        has_src_addr,
        has_dst_addr,

        has_mark,
        has_vlan,
        has_vid,
        vlan_id,

        -- * Properties

        ip_tos      ,
        ip_tot_len  ,
        ip_id       ,
        ip_frag     ,
        ip_ttl      ,
        get_mark    ,

        tcp_source  ,
        tcp_dest    ,
        tcp_hdrlen  ,

        udp_source  ,
        udp_dest    ,
        udp_len     ,

        icmp_type   ,
        icmp_code   ,

        -- * Combinators

        (.||.),
        (.&&.),
        (.^^.),
        not',
        inv ,
        par',

        -- * Comparators
        -- | Take a NetProperty, a value, and return a predicate that compares the values.

        (.<.),
        (.<=.),
        (.==.),
        (./=.),
        (.>.),
        (.>=.),
        any_bit,
        all_bit,

        -- * Conditionals

        conditional ,
        when'       ,
        unless'     ,

        -- * Filters
        -- | A collection of monadic NetFunctions.

        filter'    ,
        ip         ,
        ip6        ,
        udp        ,
        tcp        ,
        icmp       ,
        udp6       ,
        tcp6       ,
        icmp6      ,
        vlan       ,
        l3_proto   ,
        l4_proto   ,
        flow       ,
        rtp        ,

        vlan_id_filter,

        no_frag    ,
        no_more_frag,

        port       ,
        src_port   ,
        dst_port   ,

        addr       ,
        src_addr   ,
        dst_addr   ,

        -- * Steering functions
        -- | Monadic functions used to dispatch packets across sockets.
        -- They evaluate to /Steer Hash Skbuff/, if the packet has a certain property, /Drop/ otherwise.

        steer_link ,
        steer_vlan ,
        steer_ip   ,
        steer_ip6  ,
        steer_flow ,
        steer_rtp  ,
        steer_net  ,
        steer_field,

        -- * Forwarders

        kernel     ,
        broadcast  ,
        drop'      ,

        forward    ,
        forwardIO  ,

        bridge     ,
        tee        ,
        tap        ,

        -- * Logging

        log_msg    ,
        log_buff   ,
        log_packet ,

        -- * Bloom Filters

        bloom       ,
        bloom_src   ,
        bloom_dst   ,

        bloom_filter,
        bloom_src_filter,
        bloom_dst_filter,

        bloomCalcN  ,
        bloomCalcM  ,
        bloomCalcP  ,

        -- * Miscellaneous

        unit       ,
        inc        ,
        dec        ,
        mark       ,

    ) where


import Network.PFq.Lang
import Foreign.C.Types
import Data.Int

import Data.Word
import Network.Socket
import System.IO.Unsafe

import Foreign.Storable.Tuple()

-- import Data.Bits
-- import Data.Endian

-- prefix2mask :: Int -> Word32
-- prefix2mask p =  toBigEndian $ fromIntegral $ complement (shiftL (1 :: Word64) (32 - p) - 1)

-- mkNetAddr :: String -> Int -> Word64
-- mkNetAddr net p = let a = unsafePerformIO (inet_addr net)
--                       b = prefix2mask p
--                   in  shiftL (fromIntegral a :: Word64) 32 .|. (fromIntegral b :: Word64)


mkNetAddr :: String -> Int -> (Word32, CInt)
mkNetAddr net p = let a = unsafePerformIO (inet_addr net)
                  in (fromIntegral a, fromIntegral p)

mkSuperNetAddr :: String -> Int -> Int -> (Word32, CInt, CInt)
mkSuperNetAddr net p sub = let a = unsafePerformIO (inet_addr net)
                           in (fromIntegral a, fromIntegral p, fromIntegral sub)

-- Default combinators

-- | Combine two predicate expressions with a specific boolean /or/ operation.
(.||.) :: NetPredicate -> NetPredicate -> NetPredicate

-- | Combine two predicate expressions with a specific boolean /and/ operation.
(.&&.) :: NetPredicate -> NetPredicate -> NetPredicate

-- | Combine two predicate expressions with a specific boolean /xor/ operation.
(.^^.) :: NetPredicate -> NetPredicate -> NetPredicate

-- | Return a new predicate that evaluates to /True/, when the given one evaluates to
-- false, and vice versa.

not' :: NetPredicate -> NetPredicate

not' p     = Combinator1 "not"  p
p1 .||. p2 = Combinator2 "or"   p1 p2
p1 .&&. p2 = Combinator2 "and"  p1 p2
p1 .^^. p2 = Combinator2 "xor"  p1 p2

infixl 7 .&&.
infixl 6 .^^.
infixl 5 .||.

-- | Return a predicate that evaluates to /True/, if the property is less than
-- the given value. Example:
--
-- >  when (ip_ttl .<. 64) drop'

(.<.)  :: NetProperty -> Word64 -> NetPredicate
(.<=.) :: NetProperty -> Word64 -> NetPredicate
(.==.) :: NetProperty -> Word64 -> NetPredicate
(./=.) :: NetProperty -> Word64 -> NetPredicate
(.>.)  :: NetProperty -> Word64 -> NetPredicate
(.>=.) :: NetProperty -> Word64 -> NetPredicate

p .<.  x = PredicateR1 "less" p x
p .<=. x = PredicateR1 "less_eq" p x
p .==. x = PredicateR1 "equal" p x
p ./=. x = PredicateR1 "not_equal" p x
p .>.  x = PredicateR1 "greater" p x
p .>=. x = PredicateR1 "greater_eq" p x

infix 4 .<.
infix 4 .<=.
infix 4 .>.
infix 4 .>=.
infix 4 .==.
infix 4 ./=.


-- | Return a predicate that evaluates to /True/, if the property has at least
-- one bit set among those specified by the given mask.

any_bit :: NetProperty
        -> Word64       -- ^ comparison mask
        -> NetPredicate

-- | Return a predicate that evaluates to /True/, if the property has all bits
-- set among those specified in the given mask.
all_bit :: NetProperty
        -> Word64       -- ^ comparison mask
        -> NetPredicate

p `any_bit` x = PredicateR1 "any_bit" p x
p `all_bit` x = PredicateR1 "all_bit" p x


-- | Evaluate to /True/ if the SkBuff is an IPv4 packet.
is_ip         = Predicate "is_ip"
-- | Evaluate to /True/ if the SkBuff is an IPv6 packet.
is_ip6        = Predicate "is_ip6"
-- | Evaluate to /True/ if the SkBuff is an UDP packet.
is_udp        = Predicate "is_udp"
-- | Evaluate to /True/ if the SkBuff is a TCP packet.
is_tcp        = Predicate "is_tcp"
-- | Evaluate to /True/ if the SkBuff is an ICMP packet.
is_icmp       = Predicate "is_icmp"
-- | Evaluate to /True/ if the SkBuff is an UDP packet, on top of IPv6.
is_udp6       = Predicate "is_udp6"
-- | Evaluate to /True/ if the SkBuff is a TCP packet, on top of IPv6.
is_tcp6       = Predicate "is_tcp6"
-- | Evaluate to /True/ if the SkBuff is an ICMP packet, on top of IPv6.
is_icmp6      = Predicate "is_icmp6"
-- | Evaluate to /True/ if the SkBuff is an UDP or TCP packet.
is_flow       = Predicate "is_flow"
-- | Evaluate to /True/ if the SkBuff has a vlan tag.
has_vlan      = Predicate "has_vlan"
-- | Evaluate to /True/ if the SkBuff is a TCP fragment.
is_frag       = Predicate "is_frag"
-- | Evaluate to /True/ if the SkBuff is the first TCP fragment.
is_first_frag = Predicate "is_first_frag"
-- | Evaluate to /True/ if the SkBuff is a TCP fragment, but the first.
is_more_frag  = Predicate "is_more_frag"

-- | Evaluate to /True/ if the SkBuff has the given vlan id.
--
-- > has_vid 42
has_vid       = Predicate1 "has_vid"        :: CInt -> NetPredicate

-- | Evaluate to /True/ if the SkBuff has the given mark, set by 'mark' function.
--
-- > has_mark 11
has_mark      = Predicate1 "has_mark"       :: CULong -> NetPredicate

-- | Evaluate to /True/ if the SkBuff has the given Layer3 protocol.
is_l3_proto   = Predicate1 "is_l3_proto"    :: Int16 -> NetPredicate
-- | Evaluate to /True/ if the SkBuff has the given Layer4 protocol.
is_l4_proto   = Predicate1 "is_l4_proto"    :: Int8 -> NetPredicate

-- | Evaluate to /True/ if the SkBuff has the given source or destination port.
--
-- If the transport protocol is not present or has no port, the predicate evaluates to False.
--
-- > has_port 80
has_port      = Predicate1 "has_port"       :: Int16 -> NetPredicate

-- | Evaluate to /True/ if the SkBuff has the given source port.
--
-- If the transport protocol is not present or has no port, the predicate evaluates to False.
--
-- > has_src_port 20
has_src_port  = Predicate1 "has_src_port"   :: Int16 -> NetPredicate

-- | Evaluate to /True/ if the SkBuff has the given destination port.
--
-- If the transport protocol is not present or has no port, the predicate evaluates to False.
--
-- > has_dst_port 80
has_dst_port  = Predicate1 "has_dst_port"   :: Int16 -> NetPredicate

-- | Evaluate to /True/ if the source or destination IP address matches the given network address. I.e.,
--
-- > has_addr "192.168.0.0" 24
has_addr     :: String -> Int -> NetPredicate

-- | Evaluate to /True/ if the source IP address matches the given network address. I.e.,
--
-- > has_addr "192.168.0.0" 24
has_src_addr :: String -> Int -> NetPredicate

-- | Evaluate to /True/ if the destination IP address matches the given network address. I.e.,
--
-- > has_addr "192.168.0.0" 24
has_dst_addr :: String -> Int -> NetPredicate

has_addr net p     = Predicate1 "has_addr" (mkNetAddr net p)
has_src_addr net p = Predicate1 "has_src_addr" (mkNetAddr net p)
has_dst_addr net p = Predicate1 "has_dst_addr" (mkNetAddr net p)

-- | Evaluate to the mark set by 'mark' function. By default packets are marked with 0.

get_mark    = Property "get_mark"

-- | Evaluate to the /tos/ field of the IP header.
ip_tos      = Property "ip_tos"

-- | Evaluate to the /tot_len/ field of the IP header.
ip_tot_len  = Property "ip_tot_len"

-- | Evaluate to the /ip_id/ field of the IP header.
ip_id       = Property "ip_id"

-- | Evaluate to the /frag/ field of the IP header.
ip_frag     = Property "ip_frag"

-- | Evaluate to the /TTL/ field of the IP header.
ip_ttl      = Property "ip_ttl"

-- | Evaluate to the /source port/ of the TCP header.
tcp_source  = Property "tcp_source"

-- | Evaluate to the /destination port/ of the TCP header.
tcp_dest    = Property "tcp_dest"

-- | Evaluate to the /length/ field of the TCP header.
tcp_hdrlen  = Property "tcp_hdrlen"

-- | Evaluate to the /source port/ of the UDP header.
udp_source  = Property "udp_source"

-- | Evaluate to the /destination port/ of the UDP header.
udp_dest    = Property "udp_dest"

-- | Evaluate to the /length/ field of the UDP header.
udp_len     = Property "udp_len"

-- | Evaluate to the /type/ field of the ICMP header.
icmp_type   = Property "icmp_type"

-- | Evaluate to the /code/ field of the ICMP header.
icmp_code   = Property "icmp_code"


-- Predefined in-kernel computations:

-- | Dispatch the packet across the sockets
-- with a randomized algorithm that maintains the integrity of
-- physical links.
--
-- > ip >-> steer_link
--
steer_link      = MFunction "steer_link"    :: NetFunction

-- | Dispatch the packet across the sockets
-- with a randomized algorithm that maintains the integrity of
-- vlan links.
--
-- > steer_vlan
--
steer_vlan      = MFunction "steer_vlan"    :: NetFunction
-- | Dispatch the packet across the sockets
-- with a randomized algorithm that maintains the integrity of
-- IP flows.
--
-- > steer_ip
--
steer_ip        = MFunction "steer_ip"      :: NetFunction

-- | Dispatch the packet across the sockets
-- with a randomized algorithm that maintains the integrity of
-- IPv6 flows.
--
-- > steer_ip6 >-> log_msg "Steering an IPv6 packet"
--
steer_ip6       = MFunction "steer_ip6"     :: NetFunction

-- | Dispatch the packet across the sockets
-- with a randomized algorithm that maintains the integrity of
-- TCP/UDP flows.
--
-- > steer_flow >-> log_msg "Steering a flow"
--

steer_flow      = MFunction "steer_flow"    :: NetFunction

-- | Dispatch the packet across the sockets
-- with a randomized algorithm that maintains the integrity of
-- RTP/RTCP flows.
--
-- > steer_rtp
--
steer_rtp       = MFunction "steer_rtp"     :: NetFunction

-- | Dispatch the packet across the sockets
-- with a randomized algorithm that maintains the integrity of
-- sub networks.
--
-- > steer_net "192.168.0.0" 16 24
--
steer_net :: String -> Int -> Int -> NetFunction
steer_net net p sub = MFunction1 "steer_net" (mkSuperNetAddr net p sub)

-- | Dispatch the packet across the sockets
-- with a randomized algorithm. The function uses as /hash/ the field
-- of /size/ bits taken at /offset/ bytes from the beginning of the packet.

steer_field :: CInt -- ^ offset from the beginning of the packet, in bytes
            -> CInt -- ^ sizeof field in bits
            -> NetFunction
steer_field off size = MFunction2 "steer_field" off size

-- Predefined filters:

-- | Transform the given predicate in its counterpart monadic version.
-- Example:
--
-- > filter' (is_udp) >-> kernel
--
-- is logically equivalent to:
--
-- > udp >-> kernel

filter'         = MFunctionP "filter"       :: NetPredicate -> NetFunction

-- | Evaluate to /Pass SkBuff/ if it is an IPv4 packet, /Drop/ it otherwise.
ip              = MFunction "ip"            :: NetFunction
-- | Evaluate to /Pass SkBuff/ if it is an IPv6 packet, /Drop/ it otherwise.
ip6             = MFunction "ip6"           :: NetFunction
-- | Evaluate to /Pass SkBuff/ if it is an UDP packet, /Drop/ it otherwise.
udp             = MFunction "udp"           :: NetFunction
-- | Evaluate to /Pass SkBuff/ if it is a TCP packet, /Drop/ it otherwise.
tcp             = MFunction "tcp"           :: NetFunction
-- | Evaluate to /Pass SkBuff/ if it is an ICMP packet, /Drop/ it otherwise.
icmp            = MFunction "icmp"          :: NetFunction
-- | Evaluate to /Pass SkBuff/ if it is an UDP packet (on top of IPv6), /Drop/ it otherwise.
udp6            = MFunction "udp6"          :: NetFunction
-- | Evaluate to /Pass SkBuff/ if it is a TCP packet (on top of IPv6), /Drop/ it otherwise.
tcp6            = MFunction "tcp6"          :: NetFunction
-- | Evaluate to /Pass SkBuff/ if it is an ICMP packet (on top of IPv6), /Drop/ it otherwise.
icmp6           = MFunction "icmp6"         :: NetFunction
-- | Evaluate to /Pass SkBuff/ if it has a vlan tag, /Drop/ it otherwise.
vlan            = MFunction "vlan"          :: NetFunction
-- | Evaluate to /Pass SkBuff/ if it is a TCP or UDP packet, /Drop/ it otherwise.
flow            = MFunction "flow"          :: NetFunction
-- | Evaluate to /Pass SkBuff/ if it is a RTP/RTCP packet, /Drop/ it otherwise.
rtp             = MFunction "rtp"           :: NetFunction
-- | Evaluate to /Pass SkBuff/ if it is not a fragment, /Drop/ it otherwise.
no_frag         = MFunction "no_frag"       :: NetFunction
-- | Evaluate to /Pass SkBuff/ if it is not a fragment or if it's the first fragment, /Drop/ it otherwise.
no_more_frag    = MFunction "no_more_frag"  :: NetFunction

-- | Forward the packet to the given device.
-- This function is lazy, in that the action is logged and performed
-- when the computation is completely evaluated.
--
-- > forward "eth1"
forward     = MFunction1 "forward"       :: String  -> NetFunction

-- | Forward the packet to the given device and evaluates to /Drop/. Example:
--
-- > when is_udp (bridge "eth1") >-> kernel
--
-- Conditional bridge, forward the packet to eth1 if UDP, send it to the kernel
-- otherwise.

bridge      = MFunction1  "bridge"       :: String  -> NetFunction

-- | Forward the packet to the given device and, evaluates to /Pass SkBuff/ or /Drop/,
-- depending on the value returned by the predicate. Example:
--
-- > tee "eth1" is_udp >-> kernel
--
-- Logically equivalent to:
--
-- > forward "eth1" >-> udp >-> kernel
--
-- Only a little bit more efficient.

tee         = MFunction1P "tee"          :: String  -> NetPredicate -> NetFunction

-- | Evaluate to /Pass SkBuff/, or forward the packet to the given device and evaluate to /Drop/,
-- depending on the value returned by the predicate. Example:
--
-- > tap "eth1" is_udp >-> kernel
--
-- Logically equivalent to:
--
-- > unless' is_udp (forward "eth1" >-> drop') >-> kernel
--
-- Only a little bit more efficient.

tap         = MFunction1P "tap"          :: String  -> NetPredicate -> NetFunction

-- | Forward the packet to the given device. This operation breaks the purity of the language,
-- and it is possibly slower than the lazy "forward" counterpart.
--
-- > forwardIO "eth1"
forwardIO       = MFunction1 "forwardIO"     :: String -> NetFunction

-- | Send a copy of the packet to the kernel (the sk_buff may have been captured directly
-- by PFQ).
--
-- To avoid loop, this function is ignored for packets sniffed from the kernel.
kernel          = MFunction "kernel"         :: NetFunction

-- | Broadcast the packet to all the sockets that have joined the group for which this computation
-- is specified.
--
broadcast       = MFunction "broadcast"      :: NetFunction

-- | Drop the packet. The computation evaluates to /Drop/.
--
drop'           = MFunction "drop"           :: NetFunction

-- | Unit operation implements left- and right-identity for Action monad.
--
unit            = MFunction "unit"           :: NetFunction

-- | Log a message to syslog.
--
-- > udp >-> log_msg "This is an UDP packet"
log_msg         = MFunction1 "log_msg"       :: String -> NetFunction

-- | Dump the payload of packet to syslog.
--
-- > icmp >-> log_buff
log_buff        = MFunction "log_buff"       :: NetFunction

-- | Log the packet to syslog, with a syntax similar to tcpdump.
--
-- > icmp >-> log_msg "This is an ICMP packet:" >-> log_packet
log_packet      = MFunction "log_packet"     :: NetFunction

-- | Increment the i-th counter of the current group.
--
-- > inc 10
inc             = MFunction1 "inc"       :: CInt     -> NetFunction

-- | Decrement the i-th counter of the current group.
--
-- > inc 10
dec             = MFunction1 "dec"       :: CInt     -> NetFunction

-- | Mark the packet with the given value.
--
-- > mark 42
mark            = MFunction1 "mark"      :: CULong   -> NetFunction


-- | Monadic version of 'is_l3_proto' predicate.
--
-- Predicates are used in conditional expressions, while monadic functions
-- are combined with Kleisli operator:
--
-- > l3_proto 0x842 >-> log_msg "Wake-on-LAN packet!"

l3_proto        = MFunction1 "l3_proto"  :: Int16    -> NetFunction

-- | Monadic version of 'is_l4_proto' predicate.
--
-- Predicates are used in conditional expressions, while monadic functions
-- are combined with Kleisli operator:
--
-- > l4_proto 89 >-> log_msg "OSFP packet!"
l4_proto        = MFunction1 "l4_proto"  :: Int8     -> NetFunction

-- | Monadic version of 'has_port' predicate.
--
-- Predicates are used in conditional expressions, while monadic functions
-- are combined with Kleisli operator:
--
-- > port 80 >-> log_msg "http packet!"
port            = MFunction1 "port"      :: Int16    -> NetFunction
-- | Monadic version of 'has_src_port' predicate.
src_port        = MFunction1 "src_port"  :: Int16    -> NetFunction
-- | Monadic version of 'has_dst_port' predicate.
dst_port        = MFunction1 "dst_port"  :: Int16    -> NetFunction

-- | Monadic version of 'has_addr' predicate.
--
-- Predicates are used in conditional expressions, while monadic functions
-- are combined with Kleisli operator:
--
-- > addr "192.168.0.0" 24 >-> log_packet

addr     :: String -> Int -> NetFunction
-- | Monadic version of 'has_src_addr' predicate.
--
-- > src_addr "192.168.0.0" 24 >-> log_packet
src_addr :: String -> Int -> NetFunction
-- | Monadic version of 'has_src_addr' predicate.
--
-- > dst_addr "192.168.0.0" 24 >-> log_packet
dst_addr :: String -> Int -> NetFunction


addr net p      = MFunction1 "addr"     (mkNetAddr net p)
src_addr net p  = MFunction1 "src_addr" (mkNetAddr net p)
dst_addr net p  = MFunction1 "dst_addr" (mkNetAddr net p)


-- | Conditional execution of monadic NetFunctions.
--
-- The function takes a predicate and evaluates to given the NetFunction when it evalutes to /True/,
-- otherwise does nothing.
-- Example:
--
-- > when' is_tcp (log_msg "This is a TCP Packet")

when'           = MFunctionPF "when"          :: NetPredicate -> NetFunction  -> NetFunction

-- | The reverse of "when'"
unless'         = MFunctionPF "unless"        :: NetPredicate -> NetFunction  -> NetFunction

-- | Conditional execution of monadic NetFunctions.
--
-- The function takes a predicate and evaluates to the first or the second expression, depending on the
-- value returned by the predicate.
-- Example:
--
-- > conditional is_udp (forward "eth1") (forward "eth2")

conditional     = MFunctionPFF "conditional"  :: NetPredicate -> NetFunction  -> NetFunction  -> NetFunction

-- | Function that inverts a monadic NetFunction. Useful to invert filters:
--
-- > inv ip >-> log_msg "This is not an IPv4 Packet"
inv             = MFunctionF "inv"            :: NetFunction  -> NetFunction

-- | Function that returns the parallel of two monadic NetFunctions. Useful with filters:
--
-- > par' udp icmp >-> log_msg "This is an UDP or an ICMP Packet"
par'            = MFunctionFF "par"           :: NetFunction  -> NetFunction -> NetFunction

-- | Predicate which evaluates to /True/ when the packet has one of the
-- vlan id specified by the list. Example:
--
-- > when (vland_id [1,13,42,43]) msg_log "Got a packet!"

vlan_id  :: [CInt] -> NetPredicate
vlan_id ids = Predicate1 "vlan_id" (Vector ids)

-- | Monadic function, counterpart of 'vlan_id' function.
vlan_id_filter  :: [CInt] -> NetFunction
vlan_id_filter ids = MFunction1 "vlan_id_filter" (Vector ids)

-- | Predicate that evaluates to /True/ when the source or the destination address
-- of the packet matches the ones specified by the bloom list.
--
-- The first 'CInt' argument specifies the size of the bloom filter. Example:
--
-- > when (bloom 1024 ["192.168.0.13", "192.168.0.42"]) log_packet >-> kernel
--
bloom         :: CInt -> [HostName] -> NetPredicate

-- | Similarly to 'bloom', evaluates to /True/ when the source address
-- of the packet matches the ones specified by the bloom list.
bloom_src     :: CInt -> [HostName] -> NetPredicate

-- | Similarly to 'bloom', evaluates to /True/ when the destination address
-- of the packet matches the ones specified by the bloom list.
bloom_dst     :: CInt -> [HostName] -> NetPredicate

bloom_filter      :: CInt -> [HostName] -> NetFunction
bloom_src_filter  :: CInt -> [HostName] -> NetFunction
bloom_dst_filter  :: CInt -> [HostName] -> NetFunction

bloom            m hs = let ips = unsafePerformIO (mapM inet_addr hs) in Predicate2 "bloom"     m (Vector ips)
bloom_src        m hs = let ips = unsafePerformIO (mapM inet_addr hs) in Predicate2 "bloom_src" m (Vector ips)
bloom_dst        m hs = let ips = unsafePerformIO (mapM inet_addr hs) in Predicate2 "bloom_dst" m (Vector ips)

-- | Monadic counterpart of 'bloom' function.
bloom_filter     m hs = let ips = unsafePerformIO (mapM inet_addr hs) in MFunction2 "bloom_filter"     m (Vector ips)
-- | Monadic counterpart of 'bloom_src' function.
bloom_src_filter m hs = let ips = unsafePerformIO (mapM inet_addr hs) in MFunction2 "bloom_src_filter" m (Vector ips)
-- | Monadic counterpart of 'bloom_dst' function.
bloom_dst_filter m hs = let ips = unsafePerformIO (mapM inet_addr hs) in MFunction2 "bloom_dst_filter" m (Vector ips)

-- bloom filter: utility functions:

bloomK = 4

-- | Bloom filter: utility function that computes the optimal /M/, given the parameter /N/ and
-- the false-positive probability /p/.

bloomCalcM  :: Int -> Double -> Int
bloomCalcM  n p =  ceiling $ fromIntegral(-bloomK * n) / log(1 - p ** (1 / fromIntegral bloomK))

-- | Bloom filter: utility function that computes the optimal /N/, given the parameter /M/ and
-- the false-positive probability /p/.

bloomCalcN  :: Int -> Double -> Int
bloomCalcN  m p =  ceiling $ fromIntegral (-m) * log(1 - p ** (1 / fromIntegral bloomK )) / fromIntegral bloomK

-- | Bloom filter: utility function that computes the false positive P, given /N/ and /M/ parameters.

bloomCalcP  :: Int -> Int -> Double
bloomCalcP  n m =  (1 - (1 - 1 / fromIntegral m) ** fromIntegral (n * bloomK))^bloomK



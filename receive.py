#!/usr/bin/env python
import sys
import struct
import os

from scapy.all import sniff, sendp, hexdump, get_if_list, get_if_hwaddr, bind_layers
from scapy.all import Packet, IPOption
from scapy.all import ShortField, IntField, LongField, BitField, FieldListField, FieldLenField
from scapy.all import IP, UDP, Raw, TCP, Ether
from scapy.layers.inet import _IPOption_HDR

def get_if():
    ifs=get_if_list()
    iface=None
    for i in get_if_list():
        if "eth0" in i:
            iface=i
            break;
    if not iface:
        print "Cannot find eth0 interface"
        exit(1)
    return iface

def expand(x):
    yield x
    while x.payload:
        x = x.payload
        yield x

def handle_pkt(pkt):
    if WECMP in pkt or (TCP in pkt and pkt[TCP].dport == 1234):

        data_layers = [l for l in expand(pkt) if l.name=='WECMP']
        print "got a packet"
        global maxq
        for sw in data_layers:
            if sw.queue > maxq:
                maxq = sw.queue
            else:
                pass

            print "Switch {} - dir{} - pathid {} swid:{} - duration:{} - queue {} - tagid {} - maxU {} qmax {}".format(sw.src_sw_id, sw.dir, sw.selected_path_id, sw.swid, sw.duration, sw.queue, sw.tag_path_id, sw.max_utilization, maxq)
        #pkt.show2()
    #    hexdump(pkt)
            sys.stdout.flush()

class WECMP(Packet):
    name = "WECMP"
    fields_desc = [ BitField("src_sw_id", 0, 8),
                    BitField("selected_path_id", 0, 8),
                    BitField("swid", 0, 8),
                    BitField("duration", 0, 48),
                    IntField("queue", 0),
                    BitField("tag_path_id", 0, 8),
                    BitField("max_utilization", 0, 8),
                    BitField("bytes", 0, 48),
                    BitField("dir", 0, 8)]
    #def mysummary(self):
        #return self.sprintf("src_sw_id=%src_sw_id%, selected_path_id=%selected_path_id%, tag_path_id=%tag_path_id%, max_utilization=%max_utilization%")

bind_layers(Ether, WECMP, type=0x1234)
bind_layers(WECMP, IP)

def main():
    ifaces = filter(lambda i: 'eth' in i, os.listdir('/sys/class/net/'))
    iface = ifaces[0]
    print "sniffing on %s" % iface
    sys.stdout.flush()
    sniff(iface = iface,
          prn = lambda x: handle_pkt(x))

if __name__ == '__main__':
    maxq= 0
    main()

/* -*- P4_16 -*- */
#include <core.p4>
#include <v1model.p4>

// NOTE: new type added here
const bit<16> TYPE_WECMP = 0x1234;
const bit<16> TYPE_IPV4 = 0x800;

#define MAX_PORTS 3
#define MAX_QUEUE_THR 7
/*************************************************************************
*********************** H E A D E R S  ***********************************
*************************************************************************/
typedef bit<9>  egressSpec_t;
typedef bit<48> macAddr_t;
typedef bit<32> ip4Addr_t;
typedef bit<48> time_t;

header ethernet_t {
    bit<48> dstAddr;
    bit<48> srcAddr;
    bit<16> etherType;
}

header ipv4_t {
    bit<4>  version;
    bit<4>  ihl;
    bit<8>  diffserv;
    bit<16> totalLen;
    bit<16> identification;
    bit<3>  flags;
    bit<13> fragOffset;
    bit<8>  ttl;
    bit<8>  protocol;
    bit<16> hdrChecksum;
    bit<32> srcAddr;
    bit<32> dstAddr;
}

header tcp_t {
    bit<16> srcPort;
    bit<16> dstPort;
    bit<32> seqNo;
    bit<32> ackNo;
    bit<4>  dataOffset;
    bit<3>  res;
    bit<3>  ecn;
    bit<6>  ctrl;
    bit<16> window;
    bit<16> checksum;
    bit<16> urgentPtr;
}

header wecmp_t{
        bit<8> pod_dir;
    bit<8> selected_path_id;
    bit<8> output_tag
    bit<8> tag_path_id;
    bit<8> edge_flag;    
    bit<32> weighted_congestion;

    time_t duration;
    bit<32> queue;
    

    


    /* real header

    bit<8> src_sw_id;
    bit<8> selected_path_id;
    bit<8> swid;
    time_t duration;
    bit<32> queue;
    bit<8> tag_path_id;
    bit<8> max_utilization;
    bit<48> byte;
    bit<8> dir;
    */
}

struct metadata {
    bit<8> tag_id;
    bit<8> position;
    bit<8> output_tag_id;
    bit<8> src_id;
}

struct headers {
    ethernet_t ethernet;
    ipv4_t     ipv4;
    tcp_t      tcp;
    wecmp_t    wecmp;
}

/*************************************************************************
*********************** P A R S E R  ***********************************
*************************************************************************/

parser MyParser(packet_in packet,
                out headers hdr,
                inout metadata meta,
                inout standard_metadata_t standard_metadata) {

    state start {
        transition parse_ethernet;
    }
    state parse_ethernet {
        packet.extract(hdr.ethernet);
        transition select(hdr.ethernet.etherType) {
            TYPE_IPV4: parse_ipv4;
            TYPE_WECMP: parse_wecmp;
            default: accept;
        }
    }
    state parse_wecmp {
        packet.extract(hdr.wecmp);
        transition parse_ipv4;
    }
    state parse_ipv4 {
        packet.extract(hdr.ipv4);
        transition select(hdr.ipv4.protocol) {
            6: parse_tcp;
            default: accept;
        }
    }
    state parse_tcp {
        packet.extract(hdr.tcp);
        transition accept;
    }
}

/*************************************************************************
************   C H E C K S U M    V E R I F I C A T I O N   *************
*************************************************************************/

control MyVerifyChecksum(inout headers hdr, inout metadata meta) {
    apply { }
}

/*************************************************************************
**************  I N G R E S S   P R O C E S S I N G   *******************
*************************************************************************/

control MyIngress(inout headers hdr,
                  inout metadata meta,
                  inout standard_metadata_t standard_metadata) {

    /* config */
    action set_config_parameters(bit<8> id, bit<8> position) {
        meta.tag_id = id;
        meta.position = position;

    }
    table switch_config_params {
        actions = {
            set_config_parameters;
        }
        size = 1;
    }

    /* for ipv4 */
    action drop() {
        mark_to_drop(standard_metadata);
    }
    action ipv4_forward(macAddr_t dstAddr, egressSpec_t port) {
        standard_metadata.egress_spec = port;
        hdr.ethernet.srcAddr = hdr.ethernet.dstAddr;
        hdr.ethernet.dstAddr = dstAddr;
        hdr.ipv4.ttl = hdr.ipv4.ttl - 1;
    }
    table ipv4_lpm {
        key = {
            hdr.ipv4.dstAddr: lpm;
            meta.output_tag_id: exact;
        }
        actions = {
            ipv4_forward;
            drop;
            NoAction;
        }
        size = 1024;
        default_action = drop();
    }

    /* for wecmp */
    action tag_forward(egressSpec_t port){
        standard_metadata.egress_spec = port;
    }

    table output_tag_id_exact {
        key = {
            meta.output_tag_id: exact;
            meta.src_id: exact;
        }
        actions = {
            drop;
            tag_forward;
        }
        size = 1024;
        default_action = drop();
    }


    action header_process(){
        // get path id
        hdr.wecmp.selected_path_id = hdr.wecmp.selected_path_id >> 1;
        meta.output_tag_id = hdr.wecmp.selected_path_id & 1;

        // record tag path id
        hdr.wecmp.tag_path_id = hdr.wecmp.tag_path_id << 1;
        hdr.wecmp.tag_path_id = hdr.wecmp.tag_path_id | meta.tag_id;

        }


    apply {
        // configure
        switch_config_params.apply();
        meta.src_id = hdr.wecmp.src_sw_id;

        if(hdr.wecmp.isValid()){
            // sent to TOR
            if(meta.position == 2){
                if(hdr.wecmp.dir == 0){
                  header_process();
                }
                /*if(hdr.wecmp.src_sw_id == 1 && hdr.wecmp.dir == 0){
                      //standard_metadata.egress_spec = 3;
                      output_tag_id_exact.apply();
                }*/
                if(hdr.wecmp.src_sw_id == 2 && hdr.wecmp.dir == 1){
                      standard_metadata.egress_spec = 3;
                }
                else if(hdr.wecmp.src_sw_id == 1 && hdr.wecmp.dir == 1){
                    standard_metadata.egress_spec = 1;
                }
                else{
                    //standard_metadata.egress_spec = 3;
                    output_tag_id_exact.apply();
                }
            }
            // send to sw
            else if(meta.position == 1){
                if(hdr.wecmp.dir == 0){
                  header_process();
                }
                /*if(hdr.wecmp.src_sw_id == 2 && hdr.wecmp.dir == 0){
                  output_tag_id_exact.apply();
                }*/
                if(hdr.wecmp.src_sw_id == 1 && hdr.wecmp.dir == 1){
                  standard_metadata.egress_spec = 3;
                }
                else if(hdr.wecmp.src_sw_id == 2 && hdr.wecmp.dir == 1){
                    standard_metadata.egress_spec = 1;

                }
                else{
                      output_tag_id_exact.apply();
                    //standard_metadata.egress_spec = 1;
                }
            }
            else if(meta.position == 3){
                if(hdr.wecmp.dir == 0){
                  header_process();
                }
                if((hdr.wecmp.src_sw_id == 2 && hdr.wecmp.dir == 0) || (hdr.wecmp.src_sw_id == 1 && hdr.wecmp.dir == 0)){
                //ipv4_lpm.apply();
                output_tag_id_exact.apply();
                //standard_metadata.egress_spec = 3;
                }
                else if(hdr.wecmp.src_sw_id == 2 && hdr.wecmp.dir == 1){
                    standard_metadata.egress_spec = 3;
                }
                else if(hdr.wecmp.src_sw_id == 1 && hdr.wecmp.dir == 1){
                    standard_metadata.egress_spec = 1;
                }
                else{

                }
            }

        }
        else if (hdr.ipv4.isValid()) {
          //hdr.wecmp.selected_path_id = hdr.wecmp.selected_path_id >> 1;
          meta.output_tag_id = hdr.wecmp.selected_path_id & 1;
          //bit<8> output_tag_id_temp = meta.output_tag_id;
          if((hdr.ipv4.ttl == 61 && meta.position == 1) || hdr.ipv4.ttl == 61 && meta.position == 2){
            meta.output_tag_id = 2;
          }
          else{

          }
            ipv4_lpm.apply();
            //meta.output_tag_id = output_tag_id_temp;
        }
    }
}

/*************************************************************************
****************  E G R E S S   P R O C E S S I N G   *******************
*************************************************************************/
control MyEgress(inout headers hdr,
                 inout metadata meta,
                 inout standard_metadata_t standard_metadata) {

    register<bit<48>>(MAX_PORTS) byte_cnt_reg;
    register<time_t>(MAX_PORTS) last_time_reg;

    apply {

        bit<48> byte_cnt;
        bit<48> ingress_byte;
        bit<8> weight = 0;
        bit<8> weight_q = 0;
        bit<32> curr_queue = 0;
        time_t last_time;
        time_t duration;
        time_t delay;

        // record output packet bytes into the index of output port
        byte_cnt_reg.read(byte_cnt, (bit<32>)standard_metadata.egress_port);
        byte_cnt = byte_cnt + (bit<48>)standard_metadata.packet_length;
        byte_cnt_reg.write((bit<32>)standard_metadata.egress_port, byte_cnt);

        // if there is wecmp header, get utilization info
        if(hdr.wecmp.isValid()){
          if(hdr.wecmp.dir == 0){

            // read byte count of input port, get reset to 0
	        byte_cnt_reg.read(ingress_byte, (bit<32>)standard_metadata.egress_port);
	        byte_cnt_reg.write((bit<32>)standard_metadata.egress_port, 0);

            // get duration
            //curr_queue = (bit<32>) standard_metadata.deq_qdepth;
            //hdr.wecmp.queue = curr_queue;
            //hdr.wecmp.queue = 5;
            time_t cur_time = standard_metadata.ingress_global_timestamp;
            last_time_reg.read(last_time, (bit<32>)standard_metadata.egress_port);
	          last_time_reg.write((bit<32>)standard_metadata.egress_port, cur_time);
            duration = cur_time - last_time; // in micro second
            // bandwidth = 1Mbps, that is 1bit / 1ms will be the top rank(weight = 0)
            // ingress_byte is in byte unit, so << 3
            // we need 8 rank, so << more 3 bit, or we can >> duration 3 bit
            ingress_byte = ingress_byte << 6;

            hdr.wecmp.duration = ingress_byte;

            if(duration > ingress_byte){
                weight = 8;
                duration = 0; // let it not to grater than ingress_byte afterward
            }
            else{
                ingress_byte = ingress_byte - duration;
            }
            if(duration > ingress_byte){
                weight = 7;
                duration = 0; // let it not to grater than ingress_byte afterward
            }
            else{
                ingress_byte = ingress_byte - duration;
            }
            if(duration > ingress_byte){
                weight = 6;
                duration = 0; // let it not to grater than ingress_byte afterward
            }
            else{
                ingress_byte = ingress_byte - duration;
            }
            if(duration > ingress_byte){
                weight = 5;
                duration = 0; // let it not to grater than ingress_byte afterward
            }
            else{
                ingress_byte = ingress_byte - duration;
            }
            if(duration > ingress_byte){
                weight = 4;
                duration = 0; // let it not to grater than ingress_byte afterward
            }
            else{
                ingress_byte = ingress_byte - duration;
            }
            if(duration > ingress_byte){
                weight = 3;
                duration = 0; // let it not to grater than ingress_byte afterward
            }
            else{
                ingress_byte = ingress_byte - duration;
            }
            if(duration > ingress_byte){
                weight = 2;
                duration = 0; // let it not to grater than ingress_byte afterward
            }
            else{
                ingress_byte = ingress_byte - duration;
            }
            if(duration > ingress_byte){
                weight = 1;
                duration = 0; // let it not to grater than ingress_byte afterward
            }
            else{
                ingress_byte = ingress_byte - duration;

            }
            /*---------------queue------------*/
            if(curr_queue < MAX_QUEUE_THR){
                weight_q = 8;
                curr_queue = curr_queue + 64;
            }
            else{
            }

            if(curr_queue < (MAX_QUEUE_THR*2)){
                weight_q = 7;
                curr_queue = curr_queue + 64;
            }
            else{}
            if(curr_queue < (MAX_QUEUE_THR*3)){
                weight_q = 6;
                curr_queue = curr_queue + 64;
            }
            else{}
            if(curr_queue < (MAX_QUEUE_THR*4)){
                weight_q = 5;
                curr_queue = curr_queue + 64;
            }
            else{}
            if(curr_queue < (MAX_QUEUE_THR*5)){
                weight_q = 4;
                curr_queue = curr_queue + 64;
            }
            else{}
            if(curr_queue < (MAX_QUEUE_THR*6)){
                weight_q = 3;
                curr_queue = curr_queue + 64;
            }
            else{}
            if(curr_queue < (MAX_QUEUE_THR*7)){
                weight_q = 2;
                curr_queue = curr_queue + 64;
            }
            else{}
            if(curr_queue < (MAX_QUEUE_THR*8)){
                weight_q = 1;
                curr_queue = curr_queue + 64;
            }
            else{}

            // more larger the weight is, the utilization will be more less.
            // record the less one of the weight

            hdr.wecmp.max_utilization = hdr.wecmp.max_utilization + weight + weight_q;
            //hdr.wecmp.max_utilization = hdr.wecmp.max_utilization + weight;
        }
      }
    }
}

/*************************************************************************
*************   C H E C K S U M    C O M P U T A T I O N   **************
*************************************************************************/

control MyComputeChecksum(inout headers hdr, inout metadata meta) {
     apply {
	update_checksum(
	    hdr.ipv4.isValid(),
            { hdr.ipv4.version,
	      hdr.ipv4.ihl,
              hdr.ipv4.diffserv,
              hdr.ipv4.totalLen,
              hdr.ipv4.identification,
              hdr.ipv4.flags,
              hdr.ipv4.fragOffset,
              hdr.ipv4.ttl,
              hdr.ipv4.protocol,
              hdr.ipv4.srcAddr,
              hdr.ipv4.dstAddr },
            hdr.ipv4.hdrChecksum,
            HashAlgorithm.csum16);
    }
}

/*************************************************************************
***********************  D E P A R S E R  *******************************
*************************************************************************/

control MyDeparser(packet_out packet, in headers hdr) {
    apply {
        packet.emit(hdr.ethernet);
        packet.emit(hdr.wecmp);
        packet.emit(hdr.ipv4);
        packet.emit(hdr.tcp);
    }
}

/*************************************************************************
***********************  S W I T C H  *******************************
*************************************************************************/

V1Switch(
MyParser(),
MyVerifyChecksum(),
MyIngress(),
MyEgress(),
MyComputeChecksum(),
MyDeparser()
) main;

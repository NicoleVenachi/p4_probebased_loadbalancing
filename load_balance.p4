/* -*- P4_16 -*- */
#include <core.p4>
#include <v1model.p4>

// NOTE: new type added here
const bit<16> TYPE_WECMP = 0x1234;
const bit<16> TYPE_IPV4 = 0x800;
const bit<32> MAX_FLOWLET_NUM = 16;

#define PATH_NUM 8
#define INTERPACKET_GAP 48w200000
#define MAX_UTILIZATION 16
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
    bit<8> sw_id;
    bit<8> flowlet;
    bit<8> output_tag_id;

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
    action set_config_parameters(bit<8> id) {
        meta.sw_id = id;
        //hdr.wecmp.queue = (bit<32>)standard_metadata.enq_qdepth;

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
    register<time_t>(MAX_FLOWLET_NUM) last_time_reg;
    register<bit<8>>(MAX_FLOWLET_NUM) path_id_reg;
    register<bit<32>>(PATH_NUM) utilization_reg;
    register<bit<8>>(PATH_NUM) random_path_reg;

    // for counting byte and utilization
    register<bit<48>>(MAX_PORTS) byte_cnt_reg;
    register<time_t>(MAX_PORTS) last_time_cnt_reg;
    register<time_t>(MAX_PORTS) last_time_random_reg;

    action record_bytes(){
        bit<48> byte_cnt;
        // record output packet bytes into the index of output port
        byte_cnt_reg.read(byte_cnt, (bit<32>)standard_metadata.ingress_port);
        byte_cnt = byte_cnt + (bit<48>)standard_metadata.packet_length;
        byte_cnt_reg.write((bit<32>)standard_metadata.ingress_port, byte_cnt);
    }
    /*action return_wecmp(){
        hdr.wecmp.dir = 1;
        standard_metadata.egress_spec = 2;
    }*/

    action unset_wecmp_header(){
        bit<48> byte_cnt;
        bit<48> ingress_byte;
        bit<8> weight = 0;
        bit<8> weight_q = 0;
        bit<32> curr_queue = 0;
        time_t last_time;
        time_t duration;
        time_t delay;

        // read byte count of input port, get reset to 0
        byte_cnt_reg.read(ingress_byte, (bit<32>)standard_metadata.ingress_port);
        byte_cnt_reg.write((bit<32>)standard_metadata.ingress_port, 0);


        // get duration
        //curr_queue = (bit<32>) standard_metadata.deq_qdepth;
        //hdr.wecmp.queue = curr_queue;
        time_t cur_time = standard_metadata.ingress_global_timestamp;
        last_time_cnt_reg.read(last_time, (bit<32>)standard_metadata.ingress_port);
        last_time_cnt_reg.write((bit<32>)standard_metadata.ingress_port, cur_time);
        duration = cur_time - last_time; // in micro second
        //hdr.wecmp.queue = (bit<32>) standard_metadata.deq_qdepth;
        // bandwidth = 1Mbps, that is 1bit / 1ms will be the top rank(weight = 0)
        // ingress_byte is in byte unit, so << 3
        // we need 8 rank, so << more 3 bit, or we can >> duration 3 bit
        ingress_byte = ingress_byte << 6;
        hdr.wecmp.duration=ingress_byte;

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

        /*else if(hdr.wecmp.max_utilization==0){
            hdr.wecmp.max_utilization = weight;
        }*/
        // save utilization of path
        //utilization_reg.write((bit<32>)hdr.wecmp.tag_path_id, hdr.wecmp.max_utilization);

        // for testing
        //utilization_reg.write((bit<32>)hdr.wecmp.selected_path_id, hdr.wecmp.max_utilization);

        hdr.wecmp.dir = 1;
        standard_metadata.egress_spec = 2;
        // unset wecmp header
        //hdr.wecmp.setInvalid();
        //hdr.ethernet.etherType = TYPE_IPV4;

    }

    action tag_forward(egressSpec_t port){
        standard_metadata.egress_spec = port;
    }
    table output_tag_id_exact {
        key = {
            meta.output_tag_id: exact;
        }
        actions = {
            drop;
            tag_forward;
        }
        size = 1024;
        default_action = drop();
    }

    apply {
        // configure
        switch_config_params.apply();

        if (hdr.wecmp.isValid()) {
            // from host
            if(hdr.wecmp.src_sw_id == 15){
                // get flowlet index
                bit<16> wecmp_base = 0;
                hash(meta.flowlet, HashAlgorithm.crc16, wecmp_base,
	            {hdr.ipv4.srcAddr, hdr.ipv4.dstAddr, hdr.ipv4.protocol, hdr.tcp.srcPort, hdr.tcp.dstPort},
	            MAX_FLOWLET_NUM);

                // get lasttime and path id
                bit<8> path_id;
                path_id_reg.read(path_id, (bit<32>)meta.flowlet);

                time_t last_time;
                time_t last_time_random;
                time_t cur_time = standard_metadata.ingress_global_timestamp;
                last_time_reg.read(last_time, (bit<32>)meta.flowlet);
                time_t test =  cur_time - last_time;
                last_time_random_reg.read(last_time_random, 0);

                time_t random_duration = cur_time - last_time_random;
                if(cur_time - last_time > INTERPACKET_GAP){
                    // if it is new flowlet, calculate new path
                    bit<32> selection;
                    bit<8> selection_ECMP;
                    bit<32> path_utilization_0;
                    bit<32> path_utilization_1;
                    bit<32> path_utilization_2;
                    bit<32> path_utilization_3;
                    bit<32> path_utilization_4;
                    bit<32> path_utilization_5;
                    bit<32> path_utilization_6;
                    bit<32> path_utilization_7;
                    bit<8> random_path_0;
                    bit<8> random_path_1;
                    bit<8> random_path_2;
                    bit<8> random_path_3;
                    bit<8> random_path_4;
                    bit<8> random_path_5;
                    bit<8> random_path_6;
                    bit<8> random_path_7;
                    bit<32> count = 0;
                    //utilization_reg.write((bit<32>)hdr.wecmp.tag_path_id, hdr.wecmp.max_utilization);

                    utilization_reg.read(path_utilization_0, 0);
                    random_path_reg.read(random_path_0,0);
                    count = count + path_utilization_0;
                    //path_utilization_0 = count;

                    utilization_reg.read(path_utilization_1, 1);
                    random_path_reg.read(random_path_1,1);
                    count = count + path_utilization_1;
                    path_utilization_1 = count;

                    utilization_reg.read(path_utilization_2, 2);
                    random_path_reg.read(random_path_2,2);
                    count = count + path_utilization_2;
                    path_utilization_2 = count;

                    utilization_reg.read(path_utilization_3, 3);
                    random_path_reg.read(random_path_3,3);
                    count = count + path_utilization_3;
                    path_utilization_3 = count;

                    utilization_reg.read(path_utilization_4, 4);
                    random_path_reg.read(random_path_4,4);
                    count = count + path_utilization_4;
                    path_utilization_4 = count;

                    utilization_reg.read(path_utilization_5, 5);
                    random_path_reg.read(random_path_5,5);
                    count = count + path_utilization_5;
                    path_utilization_5 = count;

                    utilization_reg.read(path_utilization_6, 6);
                    random_path_reg.read(random_path_6,6);
                    count = count + path_utilization_6;
                    path_utilization_6 = count;

                    utilization_reg.read(path_utilization_7, 7);
                    random_path_reg.read(random_path_7,7);
                    count = count + path_utilization_7;
                    path_utilization_7 = count;

                    hdr.wecmp.queue =  count;

                    //hdr.wecmp.swid  = (bit<8>) count;
                    //hdr.wecmp.swid = path_utilization_2;

                    hdr.wecmp.swid = 1;

                    if(random_duration >= 500000){
                        last_time_random_reg.write(0, cur_time);
                        //hdr.wecmp.queue= (bit<32>) 120;
                        random_path_reg.write(0,0);
                        random_path_reg.write(1,0);
                        random_path_reg.write(2,0);
                        random_path_reg.write(3,0);
                        random_path_reg.write(4,0);
                        random_path_reg.write(5,0);
                        random_path_reg.write(6,0);
                        random_path_reg.write(7,0);
                        hdr.wecmp.swid = 2;
                    }
                    else{

                    }

                    //random(selection_ECMP,0,7);
                    //path_id = selection_ECMP;






                    if(random_path_0 == 0 || random_path_1 == 0 || random_path_2 == 0 || random_path_3 == 0 || random_path_3 == 4 || random_path_5 == 0 || random_path_6 == 0 || random_path_7 == 0){
                        random(selection_ECMP,0,7);
                        path_id = selection_ECMP;

                    }

                    else{
                        //hdr.wecmp.queue=15;
                        random(selection, 1, count);
                        if(selection <= path_utilization_0){
                            path_id = 0;
                        }
                        else if(selection <= path_utilization_1){
                            path_id = 1;
                        }
                        else if(selection <= path_utilization_2){
                            path_id = 2;
                        }
                        else if(selection <= path_utilization_3){
                            path_id = 3;
                        }
                        else if(selection <= path_utilization_4){
                            path_id = 4;
                        }
                        else if(selection <= path_utilization_5){
                            path_id = 5;
                        }
                        else if(selection <= path_utilization_6){
                            path_id = 6;
                        }
                        else{
                            path_id = 7;
                        }
                        // for testing
                        //hdr.wecmp.tag_path_id = path_utilization_3;
                    }



                    // write new path id into register, because of change
                    path_id_reg.write((bit<32>)meta.flowlet, path_id);
                }
                // write last time into register
                last_time_reg.write((bit<32>)meta.flowlet, cur_time);

                // setting header
                hdr.wecmp.src_sw_id = meta.sw_id;
                hdr.wecmp.selected_path_id = path_id;
                hdr.wecmp.max_utilization = 0;

                // send by tag
                //hdr.ethernet.etherType = TYPE_WECMP;
                meta.output_tag_id = hdr.wecmp.selected_path_id & 1;
                output_tag_id_exact.apply();
            }

            // send to host
            else{
                  if(hdr.wecmp.dir == 0){
                  //hdr.wecmp.queue = 11;
                  unset_wecmp_header();
                  //ipv4_lpm.apply();
                  }
                  else{
                  //hdr.wecmp.queue=12;
                  random_path_reg.write((bit<32>)hdr.wecmp.tag_path_id, 1);
                  utilization_reg.write((bit<32>)hdr.wecmp.tag_path_id, (bit<32>) hdr.wecmp.max_utilization);
                  standard_metadata.egress_spec = 3;
                  }

                }
        }
        else if(hdr.ipv4.isValid()){
        meta.output_tag_id = hdr.wecmp.selected_path_id & 1;
        //bit<8> output_tag_id_temp = meta.output_tag_id;
          if((hdr.ipv4.ttl < 64  && meta.sw_id == 1) || (hdr.ipv4.ttl < 64 && meta.sw_id == 2)){
            //ipv4_lpm_simple.apply();
            meta.output_tag_id = 2;
          }
          else{

          }
          ipv4_lpm.apply();
        //meta.output_tag_id = output_tag_id_temp;
        }

        // record bytes
        record_bytes();
    }
}

/*************************************************************************
****************  E G R E S S   P R O C E S S I N G   *******************
*************************************************************************/

control MyEgress(inout headers hdr,
                 inout metadata meta,
                 inout standard_metadata_t standard_metadata) {

    apply {
    //hdr.wecmp.queue = (bit<32>)standard_metadata.deq_qdepth;

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

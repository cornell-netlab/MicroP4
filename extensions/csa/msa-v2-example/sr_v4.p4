/*
 * Author: Myriana Rifai
 * Email: myriana.rifai@nokia-bell-labs.com
 */

#include"msa.p4"
#include"common.p4"

#define TABLE_SIZE 1024
#define ROUTER_IP 0x0a000256

struct sr4_meta_t {

}

header option_h {
	bit<3> useless;
	bit<5> option_num;
	bit<8> len;
	bit<8> data_pointer; 
}

header sr4_h {
	bit<32> 1st_addr;
	bit<32> 2nd_addr;
	bit<32> 3rd_addr;
	bit<32> 4th_addr;
	bit<32> 5th_addr;
	bit<32> 6th_addr;
	bit<32> 7th_addr;
	bit<32> 8th_addr;
	bit<32> 9th_addr;

}

struct sr4_hdr_t {
  option_h option;
  sr4_h	sr;
}



cpackage SR_v4 : implements Unicast<sr4_hdr_t, sr4_meta_t, 
                                     empty_t, empty_t, bit<16>> {
  parser micro_parser(extractor ex, pkt p, im_t im, out sr4_hdr_t hdr, inout sr4_meta_t meta,
                        in empty_t ia, inout bit<16> ethType) {
                       
                        
    state start {
    	ex.extract (p.hdr.option);
    	transition (hdr.option.option_num){
    		5x03: parse_src_routing; // loose 
    		5x09: parse_src_routing; //strict
    	}
    }
    
    state pare_src_routing{
    	ex.extract (p.hdr.sr);
    }

  }
  
  
control micro_control(pkt p, im_t im, inout sr4_hdr_t hdr, inout sr4_meta_t m,
                          in empty_t ia, out empty_t oa, inout bit<16> ioa) {
// source routing 
// need to check that the node's ip address matches one of the addresses in the sr header 
// if it does not match and we are using strict source routing (option 9) then we drop 
// if it does not match and we use loose source routing then we try to use one of the ip addresses as the nexthop, if we cannot then we set our own nexthop 
// if it matches then the nexthop is set to the next address in the list 
// the header is not modified
    action drop_action() {
            im.drop(); // Drop packet
       }
    action set_nexthop() {
    //TODO
    }
    action find_nexthop() {
    //TODO
    }
    table sr4_tbl{
    	key = {
    	hdr.option.option_num: exact;
    	hdr.sr.1st_address: exact;
    	hdr.sr.2nd_address: exact;
    	hdr.sr.3rd_address: exact;
    	hdr.sr.4th_address: exact;
    	hdr.sr.5th_address: exact;
    	hdr.sr.6th_address: exact;
    	hdr.sr.7th_address: exact;
    	hdr.sr.8th_address: exact;
    	hdr.sr.9th_address: exact;
    	}
    	actions = {
    		drop_action;
    		set_nexthop;
    		find_nexthop
    	}
    	const entries = {
    	   (5x03, ROUTER_IP,_, _ , _, _,_,_,_,_): set_nexthop(hdr.sr.2nd_address);
    	   (5x03, _,ROUTER_IP, _ , _, _,_,_,_,_): set_nexthop(hdr.sr.3rd_address);
    	   (5x03, _,_,ROUTER_IP, _, _,_,_,_,_): set_nexthop(hdr.sr.4th_address);
    	   (5x03,_,_,_,ROUTER_IP, _,_,_,_,_): set_nexthop(hdr.sr.5th_address);
    	   (5x03,_,_,_,_, ROUTER_IP,_,_,_,_): set_nexthop(hdr.sr.6th_address);
    	   (5x03,_,_,_,_,_, ROUTER_IP,_,_): set_nexthop(hdr.sr.7th_address);
    	   (5x03, _, _ , _, _,ROUTER_IP,_,_): set_nexthop(hdr.sr.8th_address);
    	   (5x03, _, _ , _, _,_,_,_,ROUTER_IP,_): set_nexthop(hdr.sr.9th_address);
    	   (5x03, _,_, _ , _, _,_,_,_,_): find_nexthop();
    	   (5x09, ROUTER_IP,_, _ , _, _,_,_,_,_): set_nexthop(hdr.sr.2nd_address);
    	   (5x09, _,ROUTER_IP, _ , _, _,_,_,_,_): set_nexthop(hdr.sr.3rd_address);
    	   (5x09, _,_,ROUTER_IP, _, _,_,_,_,_): set_nexthop(hdr.sr.4th_address);
    	   (5x09,_,_,_,ROUTER_IP, _,_,_,_,_): set_nexthop(hdr.sr.5th_address);
    	   (5x09,_,_,_,_, ROUTER_IP,_,_,_,_): set_nexthop(hdr.sr.6th_address);
    	   (5x09,_,_,_,_,_, ROUTER_IP,_,_): set_nexthop(hdr.sr.7th_address);
    	   (5x09, _, _ , _, _,ROUTER_IP,_,_): set_nexthop(hdr.sr.8th_address);
    	   (5x09, _, _ , _, _,_,_,_,ROUTER_IP,_): set_nexthop(hdr.sr.9th_address);
    	   (5x09, _,_, _ , _, _,_,_,_,_): drop_action();
    	   
    	   
    	}
    }
    
    apply {
      		sr4_tbl.apply();
    }
  }
  control micro_deparser(emitter em, pkt p, in sr4_hdr_t hdr) {
    apply {
      em.emit(p, hdr.option); 
      em.emit(p, hdr.sr);
    }
  }
}


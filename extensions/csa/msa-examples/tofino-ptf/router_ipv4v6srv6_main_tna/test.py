#
# Author: Hardik Soni
# Email: hks57@cornell.edu
#

import logging

from ptf import config
from collections import namedtuple
import ptf.testutils as testutils
from bfruntime_client_base_tests import BfRuntimeTest
import bfrt_grpc.client as gc
import grpc

logger = logging.getLogger('Test')
if not len(logger.handlers):
    logger.addHandler(logging.StreamHandler())

swports = []
for device, port, ifname in config["interfaces"]:
    logger.info("port %s device %s ifname %s", str(port), str(device), str(ifname))
    swports.append(port)
    swports.sort()

if swports == []:
    swports = range(9)


class MSARouterv46SRv6Test(BfRuntimeTest):
    """@brief Basic test for microp4 composed IPv4 and IPv6 routing
    """

    def setUp(self):
        client_id = 0
        p4_name = "router_ipv4v6srv6_main_tna"
        BfRuntimeTest.setUp(self, client_id, p4_name)

    def runTest(self):
        ig_ports = [swports[1], swports[2]]
        eg_ports = [swports[2], swports[1]]
        ipv4_2 = "10.0.2.1"
        ipv4_1 = "10.0.1.1"
        ipv6_2 = "2001:0000:0000::0000:0000:0002"
        ipv6_1 = "2001:0000:0000::0000:0000:0001"
        mac2 = "00:00:00:00:00:02"
        mac1 = "00:00:00:00:00:01"
        # send pkt and verify sent
        pkt = testutils.simple_tcp_packet(eth_dst=mac2, eth_src=mac1,
                                          ip_dst=ipv4_2, with_tcp_chksum=False)
        exp_pkt = pkt
        logger.info("Sending packet on port %d", ig_ports[0])
        testutils.send_packet(self, ig_ports[0], str(pkt))

        logger.info("Expecting packet on port %d", eg_ports[0]) 
        testutils.verify_packets(self, exp_pkt, [eg_ports[0]])

        # send pkt and verify sent
        pkt = testutils.simple_tcp_packet(eth_dst=mac1, eth_src=mac2,
                                          ip_dst=ipv4_1, with_tcp_chksum=False)
        exp_pkt = pkt
        logger.info("Sending packet on port %d", ig_ports[1])
        testutils.send_packet(self, ig_ports[1], str(pkt))

        logger.info("Expecting packet on port %d", eg_ports[1]) 
        testutils.verify_packets(self, exp_pkt, [eg_ports[1]])

        # send pkt and verify sent
        pkt = testutils.simple_tcpv6_packet(eth_dst=mac2, eth_src=mac1,
                                            ipv6_dst=ipv6_2)
        exp_pkt = pkt
        logger.info("Sending packet on port %d", ig_ports[0])
        testutils.send_packet(self, ig_ports[0], str(pkt))

        logger.info("Expecting packet on port %d", eg_ports[0]) 
        testutils.verify_packets(self, exp_pkt, [eg_ports[0]])

        # send pkt and verify sent
        pkt = testutils.simple_tcpv6_packet(eth_dst=mac1, eth_src=mac2,
                                            ipv6_dst=ipv6_1)
        exp_pkt = pkt
        logger.info("Sending packet on port %d", ig_ports[1])
        testutils.send_packet(self, ig_ports[1], str(pkt))

        logger.info("Expecting packet on port %d", eg_ports[1]) 
        testutils.verify_packets(self, exp_pkt, [eg_ports[1]])



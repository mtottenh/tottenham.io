---
layout: post
title: "XV6 - Networking Notes"
date:   2017-07-05 14:48:14 +0100
categories: xv6 intro projects
---

#Intro to XV6 Networking

## An overview of how NICs work - What does the driver do.

At it's heart, a network interface card (or NIC), is represented by two queues.
One for outgoing packets, and one for incommming packets.


Apart from those queues, the NICs also have a set of registers that control
it's behavior. For example, it has registers that determine the maximum packet
size, whether or not it should discard bad packets before storing them in the
incoming queue, whether or not to perform TCP checksum offloading, and many
other features.

The specific featureset, and register set depends on the specific NIC, but all
NICs will have an interface to setup a an incomming/outgoing packet queue. 

I've mentioned that these are 'queues', however in reality it's more like they
are circular buffers. In fact in the case of the E1000, there is a circular
buffer of descriptors, where each descriptor stores a pointer to a region of
physical memory where the packet data is stored.


#Scan the PCI Bus for valid devices

# Extract the MAC address
Specify a specific mac address
~~~bash
TOOLPREFIX=x86_64-unknown-linux-musl- make qemu QEMUEXTRA="-net nic,model=e1000,macaddr=00:12:34:56:78:9a"

#Initialize the send side


#Lets make a userspace program that will transmit a packet into the kernel

Step 1. Create a syscall that copies data from userspcae to kernel space. and then prints the packet.


Step 2. Create a userspace program that will have a fixed packet structure that calls our syscall

Once we can verify that we can copy the packet to the kernel the next step is
to copy it from the kernel buffer into the device ring buffer.

Step 3. Setup a recieving aparatus the other end to watch for our packet.

Without further ado, here is an example invocation:


$ qemu -netdev user,id=user.0,hostfwd=tcp::5555-:5556  -device e1000,netdev=user.0 -object filter-dump,id=f1,netdev=user.0,file=vm.pcap



This presents the VM with an Intel e1000 network card using QEMU's userspace
network stack (slirp). The packet capture will be written to vm.pcap.
After shutting down the VM, either inspect the packet capture on the
command-line:

$ /usr/sbin/tcpdump -nr vm.pcap

Or open it up in wireshark.

# Initialize the recieve side

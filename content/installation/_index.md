+++
title = "Installing μP4"
description = ""
weight = 1
+++

{{< lead >}}
This webpage provides the instructions to build and install μP4 and reproduce the results from the paper "Composing Dataplane Programs with μP4".

1. [As a pre-built VM](#pre-built-vm).
2. [Building and installing μP4 from source](#from-source).

**Note**: μP4 supports both v1model and Barefoot's TNA architectures. For
compiling programs for v1model, all the dependencies are publicly available.
However, if you would like to compile programs for TNA, you would need access
to Barefoot's proprietary SDE (version 9.0.0). Accordingly, the pre-built VM
has tools to support only the v1model. You would need to install Barefoot's SDE
yourself to support TNA.

## Pre-built VM

We provide a VM with μP4, along with all the dependencies, pre-installed here:
[TODO](link-to-vm).
1. Install and start [Virtualbox](https://www.virtualbox.org/wiki/Downloads) on your machine.
2. Download μP4 VM image, and import it to Virtualbox by selecting  "File" -> "Import Appliance" in Virtualbox.
3. Allocate the VM as much RAM as possible (at least 2GB). A single processor should suffice (recommended: 2).
4. You may need to turn on virtualization extensions in your BIOS to enable 64-bit virtualization.
5. When the VM starts up, the `p4` user should be automatically logged in. (username: `p4`, password: `p4`).
6. Open a terminal and verify μP4 is installed. TODO
7. To get the latest version of μP4, do `cd microp4 && git pull`. To build it, follow the instructions at https://github.com/cornell-netlab/MicroP4#2-install.

**Note**: The VM does not include Barefoot's SDE. You will need to install it yourself.

## From Source
We have released the source code for μP4 at https://github.com/cornell-netlab/MicroP4/ under an open-source license.

To build and install μP4, follow the instructions at:
https://github.com/cornell-netlab/MicroP4/tree/master#getting-started.
{{< /lead >}}



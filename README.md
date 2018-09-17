# p4-composition

The goal of the project is to enable modular development and deployment of network data plane programs written in P4 language for a specific switch architectures.

The code contains independently developed P4 prgrams, each processing packet for specific data plane functions like layer 2 switching, layer 3 routing etc..
This allows to understand separation for functionalities and study mechanisms to deploy them together on a single device.
It provides real world use cases and test scenarios to develop required composition mechanisms.

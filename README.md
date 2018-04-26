# IOTA VHDL PoW (Pearl Diver)

IOTA’s PoW needs a lot of calculation power. For instance, a test with an example transaction showed that the Raspberry needs about 90 seconds until it founds a valid nonce.

In order to speed up PoW dramatically, the IOTA Pearl-Diver algorithm was ported to a FPGA (VHDL) which enables platforms like Raspberry Pi to find a valid nonce within 2-3s.

Currently, it is running on Altera DE1 (Cyclon2 with 22kLE @ 120MHz, 85% resources used) and archives 4.2MH/s - for an arbitrary choosen transaction it took less than 2s to find a valid nonce.

This respository will not only contain VHDL source code and Altera DE1 project-files but also everything needed for a custom PCB (with a modern FPGA Cyclone 10 LP) which is plugged on top of a Raspberry Pi.

There is a fork of dcurl here which supports the FPGA here:

https://github.com/shufps/dcurl

Please have a look on the project website:

http://microengineer.eu/2018/04/25/iota-pearl-diver-fpga/


All hardware and software will become open-source.

If you think, the project is worth supporting, please consider to leave me a donation at:

LLEYMHRKXWSPMGCMZFPKKTHSEMYJTNAZXSAYZGQUEXLXEEWPXUNWBFDWESOJVLHQHXOPQEYXGIRBYTLRWHMJAOSHUY

Thank you very much :)

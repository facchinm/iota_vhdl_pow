# IOTA VHDL PoW (Pearl Diver)

IOTA PoW (proof of work) is one of the biggeste challenges for small microcontrollers - even for not so small controllers like an ARM-SoC which is used on Raspberry Pi.

This repository is about the implementation of PoW in hardware to boost PoW performance of small controllers.

Currently, it is running on Altera DE1 (Cyclon2 with 22kLE @ 120MHz, 85% resources used) and archives 4.2MH/s - for an arbitrary choosen transaction it took less than 2s to find a valid nonce.

I back-tested the VHDL core with the official Pearl-Diver implementation (IOTA IRI) and it confirmed the core is working and finding valid nonces.

TODO: insert video here

So, the prototype is done but there is much work to do.

I'm going to develop an extension PCB which fits perfectly on top of a Raspi - I think, I'll need 8 weeks from now (=mid June'18)

If you think, the project is worth supporting, please consider to leave me a tip at:

LLEYMHRKXWSPMGCMZFPKKTHSEMYJTNAZXSAYZGQUEXLXEEWPXUNWBFDWESOJVLHQHXOPQEYXGIRBYTLRWHMJAOSHUY

Thank you very much :)

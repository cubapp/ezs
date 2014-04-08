ezs
===

EZS system for Raspberry PI and a couple of switches. Switches are connected to GPIOs:
```
PIN_7, PIN_11, PIN_13, PIN_15, PIN_21, PIN_23 
```
via 1k ohm resistors. Pull up resistors 10k ohm are grounded.

The system uses perl  HiPi::Device::GPIO module for GPIO connecion, 
several WAVs to indicate pressing the switch. The program logs the 
PIN status to the file with following structure:
```
TIME, unix time, user pinout:
Sun Apr  6 19:19:53 2014,1396804793,user010000
Sun Apr  6 19:19:53 2014,1396804793,user001000

```


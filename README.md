Noisebox rev3 - Fall 2016
=========================

## Setting up RPi: 

- Flashing new disk images: 
    - https://learn.adafruit.com/beaglebone-black-installing-operating-systems/
    - https://ccrma.stanford.edu/wiki/How_To_Get_Satellite_CCRMA
    - Won't flash holding down User Boot button? Use this: http://stackoverflow.com/questions/31725206/unable-to-flash-emmc-from-sd-card-beaglebone-black
- Check current OS: http://www.cyberciti.biz/faq/find-linux-distribution-name-version-number/
    - `cat /etc/*-release`
    - `lsb_release -a`
    - `uname -a`
    - `cat /proc/version
- Remote desktop for BBB: 
    - start vncserver `vncserver -geometry 1680x1050 -depth 24`
    - Mac: open screen share and put in IP address:5901
        + PW: tightvnc
    - info:
        + https://www.digitalocean.com/community/tutorials/how-to-set-up-vnc-server-on-debian-8
        + https://www.huement.com/web/beaglebone-screen-sharing-on-osx/
    - Advertise over Bonjour (not yet working): https://teachprimarycomputing.wordpress.com/2015/02/28/a-mac-geeks-guide-to-vnc-on-the-pi/
        + Netatalk for making shared device show up - check Ivan's distro. 
- Static IPs for multiple wireless networks (new procedure on Debian Jessie)
    + https://www.raspberrypi.org/forums/viewtopic.php?f=91&t=132553
- Power switch:
    + http://www.raspberry-pi-geek.com/Archive/2013/01/Adding-an-On-Off-switch-to-your-Raspberry-Pi
    + http://www.instructables.com/id/Simple-Raspberry-Pi-Shutdown-Button/
    + Long press shut down button: https://www.raspberrypi.org/forums/viewtopic.php?f=32&t=133111
    + 


## Ingredients list for a Satellite CCRMA (or similar) Noisebox: 

- Raspberry Pi ($52) rs - http://www.robotshop.com/ca/en/raspberry-pi-3-computer-board.html
- Arduino Nano ($13) rs - http://www.robotshop.com/ca/en/pro-mini-arduino-microcontroller.html
    + teensy
- Battery ($20) - ada - https://www.adafruit.com/products/1959
    + 2.4A
- Power Supply switch ($30) rs - http://www.robotshop.com/ca/en/on-off-power-supply-switch-raspberry-pi.html
- 3 x USB cable ($9)
- microSD card ($10)
- Buttons and switches ($5)
- Sensor: Linear FSR ($10?)
- IMU ($20)
- Speaker ($4)
- Amplifier ($5)
- USB audio I/O ($5)
- Breadboard ($5)
- Housing ($10)
- Hardware and jacks ($10)
- TOTAL: $208

### Static IP setup

Write down the following information. . .

- inet addr – 192.168.1.114 (Pi's Current IP Address)
- Bcast –  192.168.1.255 (The Broadcast IP Range)
- Mask –  255.255.255.0 (Subnet Mask Address)
- Gateway - 192.168.1.1
- Destination - 192.168.1.0

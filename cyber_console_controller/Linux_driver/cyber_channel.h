#ifndef CYBER_CHANNEL_H
#define CYBER_CHANNEL_H
/*--------------------------------------------------------------------------
**
**  Copyright (c) 2013, Tom Hunter (see license.txt)
**
**  Name: cyber_channel.h
**
**  Description:
**      CDC CYBER and 6600 channel PCI card driver API.
**
**--------------------------------------------------------------------------
*/

/*
**  -------------
**  Include Files
**  -------------
*/

/*
**  ----------------
**  Public Constants
**  ----------------
*/
#define DEVICE_NODE         "/dev/cyber_channel0"
#define IOCTL_FPGA_READ     _IOR('f', 0, struct ioCb *)
#define IOCTL_FPGA_WRITE    _IOR('f', 1, struct ioCb *)

/*
**  ----------------------
**  Public Macro Functions
**  ----------------------
*/

/*
**  ----------------------------------------
**  Public Typedef and Structure Definitions
**  ----------------------------------------
*/
typedef struct ioCb
    {
    int             address;
    unsigned short  data;
    } IoCB;

/*
**  --------------------------
**  Public Function Prototypes
**  --------------------------
*/

/*
**  ----------------
**  Public Variables
**  ----------------
*/

#endif /* CYBER_CHANNEL_H */

/*---------------------------  End Of File  ------------------------------*/


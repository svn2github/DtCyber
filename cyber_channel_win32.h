/*++

Copyright (c) Microsoft Corporation.  All rights reserved.

    THIS CODE AND INFORMATION IS PROVIDED "AS IS" WITHOUT WARRANTY OF ANY
    KIND, EITHER EXPRESSED OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE
    IMPLIED WARRANTIES OF MERCHANTABILITY AND/OR FITNESS FOR A PARTICULAR
    PURPOSE.

Module Name:

    public.h

Abstract:

Environment:

    User & Kernel mode

--*/

#ifndef _PUBLIC_H
#define _PUBLIC_H

#include <initguid.h>

DEFINE_GUID(GUID_DEVINTERFACE_CYBER_CHANNEL, // Generated using guidgen.exe
0x9519364b, 0x39f3, 0x4354, 0x9b, 0xe, 0x3f, 0xa7, 0x71, 0x5b, 0xa5, 0x61);
// {9519364B-39F3-4354-9B0E-3FA7715BA561}


//
// Define the structures that will be used by the IOCTL 
//  interface to the driver
//

#define IOCTL_INDEX                     0x800
#define FILE_DEVICE_CYBER_CHANNEL       0x65500
#define IOCTL_CYBER_CHANNEL_PUT CTL_CODE(FILE_DEVICE_CYBER_CHANNEL, IOCTL_INDEX + 0, METHOD_BUFFERED, FILE_ANY_ACCESS)
#define IOCTL_CYBER_CHANNEL_GET CTL_CODE(FILE_DEVICE_CYBER_CHANNEL, IOCTL_INDEX + 1, METHOD_BUFFERED, FILE_ANY_ACCESS)

#endif


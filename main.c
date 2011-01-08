/*--------------------------------------------------------------------------
**
**  Copyright (c) 2003-2009, Tom Hunter (see license.txt)
**
**  Name: main.c
**
**  Description:
**      Perform emulation of CDC 6600 mainframe system.
**
**--------------------------------------------------------------------------
*/

/*
**  -------------
**  Include Files
**  -------------
*/
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "const.h"
#include "types.h"
#include "proto.h"
#if defined(_WIN32)
#include <windows.h>
#else
#include <unistd.h>
#endif

/*
**  -----------------
**  Private Constants
**  -----------------
*/

/*
**  -----------------------
**  Private Macro Functions
**  -----------------------
*/

/*
**  -----------------------------------------
**  Private Typedef and Structure Definitions
**  -----------------------------------------
*/

/*
**  ---------------------------
**  Private Function Prototypes
**  ---------------------------
*/
static void waitTerminationMessage(void);

/*
**  ----------------
**  Public Variables
**  ----------------
*/
char ppKeyIn;
bool emulationActive = TRUE;
u32 cycles;
#if CcCycleTime
double cycleTime;
#endif

/*
**  -----------------
**  Private Variables
**  -----------------
*/

/*
**--------------------------------------------------------------------------
**
**  Public Functions
**
**--------------------------------------------------------------------------
*/

/*--------------------------------------------------------------------------
**  Purpose:        System initialisation and main program loop.
**
**  Parameters:     Name        Description.
**                  argc        Argument count.
**                  argv        Array of argument strings.
**
**  Returns:        Zero.
**
**------------------------------------------------------------------------*/
int main(int argc, char **argv)
    {
    (void)argc;
    (void)argv;

    /*
    **  Setup exit handling.
    */
    atexit(waitTerminationMessage);

    /*
    **  Setup error logging.
    */
    logInit();

    /*
    **  Allow optional command line parameter to specify section to run in "cyber.ini".
    */
    if (argc == 2)
        {
        initStartup(argv[1]);
        }
    else
        {
        initStartup("cyber");
        }

    /*
    **  Setup debug support.
    */
#if CcDebug == 1
    traceInit();
    dumpInit();
#endif

    /*
    **  Setup operator interface.
    */
    opInit();

    /*
    **  Initiate deadstart sequence.
    */
    deadStart();

    /*
    **  Emulation loop.
    */
    while (emulationActive)
        {
#if CcCycleTime
        rtcStartTimer();
#endif

        /*
        **  Count major cycles.
        */
        cycles++;

        /*
        **  Deal with operator interface requests.
        */
        if (opActive)
            {
            opRequest();
            }

        /*
        **  Execute PP, CPU and RTC.
        */
        ppStep();
        cpuStep();
        cpuStep();
        cpuStep();
        cpuStep();
        channelStep();
        rtcTick();

#if CcCycleTime
        cycleTime = rtcStopTimer();
#endif
        }

#if CcDebug == 1
    /*
    **  Example post-mortem dumps.
    */
#if 0
    dumpAll();
    dumpPpu(0);
    dumpDisassemblePpu(0);
    dumpCpu();
#else
    dumpAll();
#endif
#endif

    /*
    **  Shut down debug support.
    */
#if CcDebug == 1
    traceTerminate();
    dumpTerminate();
#endif

    /*
    **  Shut down emulation.
    */
    windowTerminate();
    cpuTerminate();
    ppTerminate();
    channelTerminate();

    exit(0);
    }


/*
**--------------------------------------------------------------------------
**
**  Private Functions
**
**--------------------------------------------------------------------------
*/

/*--------------------------------------------------------------------------
**  Purpose:        Wait to display shutdown message.
**
**  Parameters:     Name        Description.
**
**  Returns:        Nothing.
**
**------------------------------------------------------------------------*/
static void waitTerminationMessage(void)
    {
    fflush(stdout);
    #if defined(_WIN32)
        Sleep(3000);
    #else
        sleep(3);
    #endif
    }

/*---------------------------  End Of File  ------------------------------*/

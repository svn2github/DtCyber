/*--------------------------------------------------------------------------
**
**  Copyright (c) 2003-2011, Tom Hunter
**
**  Name: npu_net.c
**
**  Description:
**      Provides TCP/IP networking interface to the ASYNC TIP in an NPU
**      consisting of a CDC 2550 HCP running CCP.
**
**  This program is free software: you can redistribute it and/or modify
**  it under the terms of the GNU General Public License version 3 as
**  published by the Free Software Foundation.
**  
**  This program is distributed in the hope that it will be useful,
**  but WITHOUT ANY WARRANTY; without even the implied warranty of
**  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
**  GNU General Public License version 3 for more details.
**  
**  You should have received a copy of the GNU General Public License
**  version 3 along with this program in file "license-gpl-3.0.txt".
**  If not, see <http://www.gnu.org/licenses/gpl-3.0.txt>.
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
#include "const.h"
#include "types.h"
#include "proto.h"
#include "npu.h"
#include <sys/types.h>
#include <memory.h>
#if defined(_WIN32)
#include <winsock.h>
#else
#include <pthread.h>
#include <unistd.h>
#include <fcntl.h>
#include <errno.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <signal.h>
#endif

/*
**  -----------------
**  Private Constants
**  -----------------
*/
#define Ms200       200000

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
static void npuNetCreateThread(void);
#if defined(_WIN32)
static void npuNetThread(void *param);
#else
static void *npuNetThread(void *param);
#endif
static void npuNetQueueOutput(Tcb *tp, u8 *data, int len);
static void npuNetTryOutput(Tcb *tp);

/*
**  ----------------
**  Public Variables
**  ----------------
*/
u16 npuNetTelnetPort = 6610;
u16 npuNetTelnetConns = 10;

/*
**  -----------------
**  Private Variables
**  -----------------
*/
static char connectingMsg[] = "\r\nConnecting to host - please wait ...\r\n";
static char connectedMsg[] = "\r\nConnected\r\n\n";
static char abortMsg[] = "\r\nConnection aborted\r\n";
static char networkDownMsg[] = "Network going down - connection aborted\r\n";
static char notReadyMsg[] = "\r\nHost not ready to accept connections - please try again later.\r\n";
static char noPortsAvailMsg[] = "\r\nNo free ports available - please try again later.\r\n";

static fd_set readFds;
static fd_set writeFds;

static int pollIndex = 0;

/*
**--------------------------------------------------------------------------
**
**  Public Functions
**
**--------------------------------------------------------------------------
*/

/*--------------------------------------------------------------------------
**  Purpose:        Initialise network connection handler.
**
**  Parameters:     Name        Description.
**
**  Returns:        Nothing.
**
**------------------------------------------------------------------------*/
void npuNetInit(void)
    {
    int i;
    Tcb *tp = npuTcbs;

    /*
    **  Initialise network part of TCBs.
    */
    for (i = 0; i < npuNetTelnetConns; i++, tp++)
        {
        tp->state = StTermIdle;
        tp->connFd = 0;
        }

    /*
    **  Setup for input data processing.
    */
    pollIndex = npuNetTelnetConns;

    /*
    **  Disable SIGPIPE which some non-Win32 platform generate on disconnect.
    */
    #ifndef WIN32
    signal(SIGPIPE, SIG_IGN);
    #endif

    /*
    **  Create the thread which will deal with TCP connections.
    */
    npuNetCreateThread();
    }
/*--------------------------------------------------------------------------
**  Purpose:        Reset network connection handler when network is going
**                  down.
**
**  Parameters:     Name        Description.
**
**  Returns:        Nothing.
**
**------------------------------------------------------------------------*/
void npuNetReset(void)
    {
    int i;
    Tcb *tp = npuTcbs;

    /*
    **  Iterate through all TCBs.
    */
    for (i = 0; i < npuNetTelnetConns; i++, tp++)
        {
        if (tp->state != StTermIdle)
            {
            /*
            **  Notify user that network is going down and then disconnect.
            */
            send(tp->connFd, networkDownMsg, sizeof(networkDownMsg) - 1, 0);

            #if defined(_WIN32)
                closesocket(tp->connFd);
            #else
                close(tp->connFd);
            #endif

            tp->state = StTermIdle;
            tp->connFd = 0;
            }
        }
    }


/*--------------------------------------------------------------------------
**  Purpose:        Signal from host that connection has been established.
**
**  Parameters:     Name        Description.
**                  tp          TCB pointer
**
**  Returns:        Nothing.
**
**------------------------------------------------------------------------*/
void npuNetConnected(Tcb *tp)
    {
    tp->state = StTermHostConnected;
    send(tp->connFd, connectedMsg, sizeof(connectedMsg) - 1, 0);
    }

/*--------------------------------------------------------------------------
**  Purpose:        Signal from host that connection has been terminated.
**
**  Parameters:     Name        Description.
**                  tp          TCB pointer
**
**  Returns:        Nothing.
**
**------------------------------------------------------------------------*/
void npuNetDisconnected(Tcb *tp)
    {
    /*
    **  Received disconnect - close socket.
    */
#if defined(_WIN32)
    closesocket(tp->connFd);
#else
    close(tp->connFd);
#endif

    /*
    **  Cleanup connection.
    */
    tp->state = StTermIdle;
    npuLogMessage("npuNet: Connection dropped on port %d\n", tp->portNumber);
    }

/*--------------------------------------------------------------------------
**  Purpose:        Prepare to send data to terminal.
**
**  Parameters:     Name        Description.
**                  tp          TCB pointer
**                  data        data address
**                  len         data length
**
**  Returns:        Nothing.
**
**------------------------------------------------------------------------*/
void npuNetSend(Tcb *tp, u8 *data, int len)
    {
#if CcTelnet
    /*
    **  Telnet escape processing is expensive and is disabled by default.
    */
    u8 *p;
    int count;

    for (p = data; len > 0; len -= 1)
        {
        switch (*p++)
            {
        case 0xFF:
            /*
            **  Double FF to escape the Telnet IAC code making it a real FF.
            */
            count = p - data;
            npuNetQueueOutput(tp, data, count);
            npuNetQueueOutput(tp, "\xFF", 1);
            data = p;
            break;

        case 0x0D:
            /*
            **  Append zero to CR otherwise real zeroes will be stripped by Telnet.
            */
            count = p - data;
            npuNetQueueOutput(tp, data, count);
            npuNetQueueOutput(tp, "\x00", 1);
            data = p;
            break;
            }
        }

    if ((count = p - data) > 0)
        {
        npuNetQueueOutput(tp, data, count);
        }
#else
    /*
    **  Standard (non-Telnet) TCP connection.
    */
    npuNetQueueOutput(tp, data, len);
#endif
    }

/*--------------------------------------------------------------------------
**  Purpose:        Store block sequence number to acknowledge when send
**                  has completed in last buffer.
**
**  Parameters:     Name        Description.
**                  tp          TCB pointer
**                  blockSeqNo  block sequence number to acknowledge.
**
**  Returns:        Nothing.
**
**------------------------------------------------------------------------*/
void npuNetQueueAck(Tcb *tp, u8 blockSeqNo)
    {
    NpuBuffer *bp;

    /*
    **  Try to use the last pending buffer unless it carries a sequence number
    **  which must be acknowledged. If there is none, get a new one and queue it.
    */
    bp = npuBipQueueGetLast(&tp->outputQ);
    if (bp == NULL || bp->blockSeqNo != 0)
        {
        bp = npuBipBufGet();
        npuBipQueueAppend(bp, &tp->outputQ);
        }

    if (bp != NULL)
        {
        bp->blockSeqNo = blockSeqNo;
        }

    /*
    **  Try to output the data on the network connection.
    */
    npuNetTryOutput(tp);
    }

/*--------------------------------------------------------------------------
**  Purpose:        Check for network status.
**
**  Parameters:     Name        Description.
**
**  Returns:        Nothing.
**
**------------------------------------------------------------------------*/
void npuNetCheckStatus(void)
    {
    struct timeval timeout;
    int readySockets = 0;
    Tcb *tp;

    timeout.tv_sec = 0;
    timeout.tv_usec = 0;

    while (pollIndex < npuNetTelnetConns)
        {
        tp = npuTcbs + pollIndex++;

        if (tp->state == StTermIdle)
            {
            continue;
            }

        /*
        **  Handle transparent input timeout.
        */
        if (tp->xInputTimerRunning && (cycles - tp->xStartCycle) >= Ms200)
            {
            npuAsyncFlushUplineTransparent(tp);
            }

        /*
        **  Handle network traffic.
        */
        FD_ZERO(&readFds);
        FD_ZERO(&writeFds);
        FD_SET(tp->connFd, &readFds);
        FD_SET(tp->connFd, &writeFds);
        readySockets = select(tp->connFd + 1, &readFds, &writeFds, NULL, &timeout);
        if (readySockets <= 0)
            {
            continue;
            }

        if (npuBipQueueNotEmpty(&tp->outputQ) && FD_ISSET(tp->connFd, &writeFds))
            {
            /*
            **  Send data if any is pending.
            */
            npuNetTryOutput(tp);
            }

        if (FD_ISSET(tp->connFd, &readFds))
            {
            /*
            **  Receive a block of data.
            */
            tp->inputCount = recv(tp->connFd, tp->inputData, sizeof(tp->inputData), 0);
            if (tp->inputCount <= 0)
                {
                /*
                **  Received disconnect - close socket.
                */
            #if defined(_WIN32)
                closesocket(tp->connFd);
            #else
                close(tp->connFd);
            #endif

                npuLogMessage("npuNet: Connection dropped on port %d\n", tp->portNumber);

                /*
                **  Notify SVM.
                */
                npuSvmDiscRequestTerminal(tp);
                }
            else if (tp->state == StTermHostConnected)
                {
                /*
                **  Hand up to the ASYNC TIP.
                */
                npuAsyncProcessUplineData(tp);
                }

            /*
            **  The following return ensures that we resume with polling the next
            **  connection in sequence otherwise low-numbered connections would get
            **  preferential treatment.
            */
            return;
            }
        }

    pollIndex = 0;
    }

/*
**--------------------------------------------------------------------------
**
**  Private Functions
**
**--------------------------------------------------------------------------
*/

/*--------------------------------------------------------------------------
**  Purpose:        Create thread which will deal with all TCP
**                  connections.
**
**  Parameters:     Name        Description.
**
**  Returns:        Nothing.
**
**------------------------------------------------------------------------*/
static void npuNetCreateThread(void)
    {
#if defined(_WIN32)
    WORD versionRequested;
    WSADATA wsaData;
    int err;
    DWORD dwThreadId; 
    HANDLE hThread;

#if 1
// <<<<<<<<<<<<<<< should really only call this once application wide >>>>>>>>>>>>>>>>
    /*
    **  Select WINSOCK 1.1.
    */ 
    versionRequested = MAKEWORD(1, 1);

    err = WSAStartup(versionRequested, &wsaData);
    if (err != 0)
        {
        fprintf(stderr, "\r\nError in WSAStartup: %d\r\n", err);
        exit(1);
        }
#endif

    /*
    **  Create TCP thread.
    */
    hThread = CreateThread( 
        NULL,                                       // no security attribute 
        0,                                          // default stack size 
        (LPTHREAD_START_ROUTINE)npuNetThread, 
        (LPVOID)NULL,                               // thread parameter 
        0,                                          // not suspended 
        &dwThreadId);                               // returns thread ID 

    if (hThread == NULL)
        {
        fprintf(stderr, "Failed to create npuNet thread\n");
        exit(1);
        }
#else
    int rc;
    pthread_t thread;
    pthread_attr_t attr;

    /*
    **  Create POSIX thread with default attributes.
    */
    pthread_attr_init(&attr);
    rc = pthread_create(&thread, &attr, npuNetThread, NULL);
    if (rc < 0)
        {
        fprintf(stderr, "Failed to create npuNet thread\n");
        exit(1);
        }
#endif
    }

/*--------------------------------------------------------------------------
**  Purpose:        TCP thread.
**
**  Parameters:     Name        Description.
**                  mp          pointer to mux parameters.
**
**  Returns:        Nothing.
**
**------------------------------------------------------------------------*/
#if defined(_WIN32)
static void npuNetThread(void *param)
#else
static void *npuNetThread(void *param)
#endif
    {
    int listenFd;
    int acceptFd;
    struct sockaddr_in server;
    struct sockaddr_in from;
    u8 i;
    Tcb *tp;
    int optEnable = 1;
#if defined(_WIN32)
    int fromLen;
    u_long blockEnable = 1;
#else
    socklen_t fromLen;
#endif

    /*
    **  Create TCP socket and bind to specified port.
    */
    listenFd = socket(AF_INET, SOCK_STREAM, 0);
    if (listenFd < 0)
        {
        fprintf(stderr, "npuNet: Can't create socket\n");
#if defined(_WIN32)
        return;
#else
        return(NULL);
#endif
        }

    setsockopt(listenFd, SOL_SOCKET, SO_REUSEADDR, (void *)&optEnable, sizeof(optEnable));
    memset(&server, 0, sizeof(server));
    server.sin_family = AF_INET;
    server.sin_addr.s_addr = inet_addr("0.0.0.0");
    server.sin_port = htons(npuNetTelnetPort);

    if (bind(listenFd, (struct sockaddr *)&server, sizeof(server)) < 0)
        {
        fprintf(stderr, "npuNet: Can't bind to socket\n");
#if defined(_WIN32)
        return;
#else
        return(NULL);
#endif
        }

    if (listen(listenFd, 5) < 0)
        {
        fprintf(stderr, "npuNet: Can't listen\n");
#if defined(_WIN32)
        return;
#else
        return(NULL);
#endif
        }

    while (1)
        {
        /*
        **  Wait for a connection.
        */
        fromLen = sizeof(from);
        acceptFd = accept(listenFd, (struct sockaddr *)&from, &fromLen);

        /*
        **  Set Keepalive option so that we can eventually discover if
        **  a client has been rebooted.
        */
        setsockopt(acceptFd, SOL_SOCKET, SO_KEEPALIVE, (void *)&optEnable, sizeof(optEnable));

        /*
        **  Make socket non-blocking.
        */
#if defined(_WIN32)
        ioctlsocket(acceptFd, FIONBIO, &blockEnable);
#else
        fcntl(acceptFd, F_SETFL, O_NONBLOCK);
#endif

        /*
        **  Check if the host is ready to accept connections.
        */
        if (!npuSvmIsReady())
            {
            /*
            **  Tell the user.
            */
            send(acceptFd, notReadyMsg, sizeof(notReadyMsg) - 1, 0);

            /*
            **  Wait a bit and then disconnect.
            */
        #if defined(_WIN32)
            Sleep(2000);
            closesocket(acceptFd);
        #else
            sleep(2);
            close(acceptFd);
        #endif

            continue;
            }

        /*
        **  Find a free TCB.
        */
        tp = npuTcbs;
        for (i = 0; i < npuNetTelnetConns; i++)
            {
            if (tp->state == StTermIdle)
                {
                break;
                }

            tp += 1;
            }

        /*
        **  Did we find a free TCB?
        */
        if (i == npuNetTelnetConns)
            {
            /*
            **  No free port found - tell the user.
            */
            send(acceptFd, noPortsAvailMsg, sizeof(noPortsAvailMsg) - 1, 0);

            /*
            **  Wait a bit and then disconnect.
            */
        #if defined(_WIN32)
            Sleep(2000);
            closesocket(acceptFd);
        #else
            sleep(2);
            close(acceptFd);
        #endif

            continue;
            }

        /*
        **  Mark connection as active.
        */
        tp->connFd = acceptFd;
        tp->state = StTermNetConnected;
        npuLogMessage("npuNet: Received connection on port %u\n", tp->portNumber);

        /*
        **  Notify user of connect attempt.
        */
        send(tp->connFd, connectingMsg, sizeof(connectingMsg) - 1, 0);

        /*
        **  Attempt connection to host.
        */
        if (!npuSvmConnectTerminal(tp))
            {
            /*
            **  No buffers, notify user.
            */
            send(tp->connFd, abortMsg, sizeof(abortMsg) - 1, 0);

            /*
            **  Wait a bit and then disconnect.
            */
        #if defined(_WIN32)
            Sleep(1000);
            closesocket(tp->connFd);
        #else
            sleep(1);
            close(tp->connFd);
        #endif
            
            tp->state = StTermIdle;
            }
        }

#if !defined(_WIN32)
    return(NULL);
#endif
    }

/*--------------------------------------------------------------------------
**  Purpose:        Queue output to terminal and do basic Telnet formatting.
**
**  Parameters:     Name        Description.
**                  tp          TCB pointer
**                  data        data address
**                  len         data length
**
**  Returns:        Nothing.
**
**------------------------------------------------------------------------*/
static void npuNetQueueOutput(Tcb *tp, u8 *data, int len)
    {
    NpuBuffer *bp;
    u8 *startAddress;
    int byteCount;

    /*
    **  Try to use the last pending buffer unless it carries a sequence number
    **  which must be acknowledged. If there is none, get a new one and queue it.
    */
    bp = npuBipQueueGetLast(&tp->outputQ);
    if (bp == NULL || bp->blockSeqNo != 0)
        {
        bp = npuBipBufGet();
        npuBipQueueAppend(bp, &tp->outputQ);
        }

    while (bp != NULL && len > 0)
        {
        /*
        **  Append data to the buffer.
        */
        startAddress = bp->data + bp->offset + bp->numBytes;
        byteCount = MaxBuffer - bp->offset - bp->numBytes;
        if (byteCount >= len)
            {
            byteCount = len;
            }

        memcpy(startAddress, data, byteCount);
        bp->numBytes += byteCount;

        /*
        **  If there is still data left get a new buffer, queue it and
        **  copy what is left.
        */
        len -= byteCount;
        if (len > 0)
            {
            bp = npuBipBufGet();
            npuBipQueueAppend(bp, &tp->outputQ);
            }
        }
    }

/*--------------------------------------------------------------------------
**  Purpose:        Try to send any queued data.
**
**  Parameters:     Name        Description.
**                  tp          TCB pointer
**
**  Returns:        Nothing.
**
**------------------------------------------------------------------------*/
static void npuNetTryOutput(Tcb *tp)
    {
    NpuBuffer *bp;
    u8 *data;
    int result;

    /*
    **  Return if we are flow controlled.
    */
    if (tp->xoff)
        {
        return;
        }

    /*
    **  Process all queued output buffers.
    */
    while ((bp = npuBipQueueExtract(&tp->outputQ)) != NULL)
        {
        data = bp->data + bp->offset;

        /*
        **  Don't call into TCP if there is no data to send.
        */
        if (bp->numBytes > 0)
            {
            result = send(tp->connFd, data, bp->numBytes, 0);
            }
        else
            {
            result = 0;
            }

        if (result >= bp->numBytes)
            {
            /*
            **  The socket took all our data - let TIP know what block sequence 
            **  number we processed, free the buffer and then continue.
            */
            if (bp->blockSeqNo != 0)
                {
                npuTipNotifySent(tp, bp->blockSeqNo);
                }

            npuBipBufRelease(bp);
            continue;
            }

        /*
        **  Not all has been sent. Put the buffer back into the queue.
        */
        npuBipQueuePrepend(bp, &tp->outputQ);

        /*
        **  Was there an error?
        */
        if (result < 0)
            {
            /*
            **  Likely this is a "would block" type of error - no need to do
            **  anything here. The select() call will later tell us when we
            **  can send again. Any disconnects or other errors will be handled
            **  by the receive handler.
            */
            return;
            }

        /*
        **  The socket did not take all data - update offset and count.
        */
        if (result > 0)
            {
            bp->offset   += result;
            bp->numBytes -= result;
            }
        }
    }

/*---------------------------  End Of File  ------------------------------*/

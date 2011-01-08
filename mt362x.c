/*--------------------------------------------------------------------------
**
**  Copyright (c) 2003, Tom Hunter (see license.txt)
**
**  Name: mt3000.c
**
**  Description:
**      Perform simulation of CDC 362x tape controller.
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

/*
**  -----------------
**  Private Constants
**  -----------------
*/

/*
**  CDC 362x tape function and status codes.
**  
**  0000    Release
**  0001    Select Binary
**  0002    Select Coded (i.e. BCD)
**  0003    Select 556 bpi
**  0004    Select 200 bpi
**  0005    Clear
**  0006    Select 800 bpi
**  0010    Rewind
**  0011    Rewind Unload
**  0012    Backspace
**  0013	Search Forward to File Mark
**  0014	Search Backward to File Mark
**	0015	Write Tape Mark
**	0016	Skip Bad Spot
**	0020	Select Interrupt on Ready and Not Busy
**	0021	Release Interrupt on Ready and Not Busy
**	0022	Select Interrupt on End of Operation
**	0023	Release Interrupt on End of Operation
**	0024	Select Interrupt on Abnormal End of Operation
**	0025	Release Interrupt on End of Operation
**	0040	Clear Reverse Read (Select Forward Read)
**	0041	Toggle Read Direction
**	10UU	Connect Unit (Equipment 1)
**	20UU	Connect Unit (Equipment 2)
**	30UU	Connect Unit (Equipment 3)
**	40UU	Connect Unit (Equipment 4)
**	50UU	Connect Unit (Equipment 5)
**	60UU	Connect Unit (Equipment 6)
**	70UU	Connect Unit (Equipment 7)
*/

#define Fc362xRelease			00000
#define Fc362xSelectBinary		00001
#define Fc362xSelectCoded		00002
#define Fc362xSelect556Bpi		00003
#define Fc362xSelect200Bpi		00004
#define Fc362xClear				00005
#define Fc362xSelect800Bpi		00006
#define Fc362xRewind			00010
#define Fc362xRewindUnload		00011
#define Fc362xBackspace			00012
#define Fc362xSearchFwdFileMark	00013
#define Fc362xSearchBckFileMark	00014
#define Fc362xWriteFileMark		00015
#define Fc362xSkipBadSpot		00016
#define Fc362xSelectIntReady	00020
#define Fc362xReleaseIntReady	00021
#define Fc362xSelectIntEndOfOp	00022
#define Fc362xReleaseIntEndOfOp	00023
#define	Fc362xSelectIntError	00024
#define Fc362xReleaseIntError	00025
#define Fc362xClearReverseRead	00040
#define Fc362xSetReverseRead	00041
#define Fc362xConnectUnitEqp1	01000
#define Fc362xConnectUnitEqp2	02000
#define	Fc362xConnectUnitEqp3	03000
#define Fc362xConnectUnitEqp4	04000
#define Fc362xConnectUnitEqp5	05000
#define Fc362xConnectUnitEqp6	06000
#define Fc362xConnectUnitEqp7	07000

#define Fc362xConnectMask		07700
#define Fc362xUnitMask			00017
/*
**	dcc6681 functions
*/
#define Fc6681DevStatusReq      01300
#define Fc6681InputToEor        01400
#define Fc6681Input             01500
#define Fc6681Output            01600
#define Fc6681MasterClear       01700

#define Int362xReady			00001
#define Int362xEndOfOp			00002
#define Int362xError			00004

/*
**  
**  Status Reply:
**
**  xxx1 = Ready
**  xxx2 = Control and/or Unit Busy
**  xxx4 = Write Enable
**  xx1x = File Mark
**  xx2x = Load Point
**  xx4x = End of Tape
**  x0xx = Density 200 Bpi
**  x1xx = Density 556 Bpi
**  x2xx = Density 800 Bpi
**  x4xx = Lost Data
**  1xxx = End of Operation
**	2xxx = Verical or Longitudal Parity Error
**	4xxx = Reserved by Other Controller
**  
*/
#define St362xReadyMask			00003	// Also includes Busy
#define St362xWriteMask			00007	// Also includes Busy, Ready
#define St362xWriteReady		00005
#define St362xNonDensityMask	07475
#define St362xConnectClr		03367
#define St362xClearMask			01765	// Clears Parity, File Mark, Busy
#define St362xMstrClrMask		01365
#define St362xTpMotionClr		03305
#define St362xDensityParity		03300
#define St362xRWclear			01305
#define St362xClearBusy			07775

#define St362xReady             00001
#define St362xBusy				00002
#define St362xWriteEnable		00004
#define St362xFileMark			00010
#define St362xLoadPoint			00020
#define St362xEndOfTape			00040
#define St362xDensity556Bpi		00100
#define St362xDensity800Bpi		00200
#define St362xLostData			00400
#define St362xEndOfOperation	01000
#define St362xParityError		02000
#define St362xUnitReserved		04000

/*
**  Misc constants.
*/
#define MaxPpBuf                010000
#define MaxByteBuf              014000

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
typedef struct tapeBuf
    {
	PpWord      ioBuffer[MaxPpBuf];
	PpWord		intMask;
	PpWord		intStatus;
	bool		unitExists[16];
	bool		bcdMode;
	bool		reverseRead;
	PpWord		status[16];
	u32			byteCount;
	u32			ppWordCount;
	u32			curPpWord;
	FILE		*fcb[16];
	u8			connectedUnit;
    } MtContext;

/*
**  ---------------------------
**  Private Function Prototypes
**  ---------------------------
*/
static FcStatus mt362xFunc(PpWord funcCode);
static void mt362xIo(void);
static void mt362xActivate(void);
static void mt362xDisconnect(void);
static void mt362xLoad(Dev3kSlot *dp, char *fn);
static void mt362xSkipBackward(MtContext *tp);
static void mt362xSkipForward(MtContext *tp);
static void mt362xUnload(MtContext *tp);

/*
**  ----------------
**  Public Variables
**  ----------------
*/

/*
**  -----------------
**  Private Variables
**  -----------------
*/
static char str[200];

/*
**--------------------------------------------------------------------------
**
**  Public Functions
**
**--------------------------------------------------------------------------
*/
/*--------------------------------------------------------------------------
**  Purpose:        Initialise 607 tape drives.
**
**  Parameters:     Name        Description.
**                  eqNo        equipment number
**                  unitNo      unit number
**                  channelNo   channel number the device is attached to
**                  deviceName  optional device file name
**
**  Returns:        Nothing.
**
**------------------------------------------------------------------------*/
void mt362xInit(u8 unitNo, u8 eqNo, u8 channelNo, char *deviceName)
        {
    DevSlot *cp;
	Dev3kSlot *ep;
	MtContext *mp;
	u8 trueUnitNo;
	int u;

	/* 
	** Locate 6681 converter.  Attach this controller if the converter
	** doesn't already exist (it will be created), or if the converter
	** exists, but this controller is not already attached.
	*/

    cp = channelFindDevice(channelNo, DtDdc6681);
	if (NULL != cp)
	    {
		ep = cp->context[eqNo];
		if (ep == NULL)
			ep = dcc6681Attach(channelNo, eqNo, DtMt362x);
	    }
	else
		ep = dcc6681Attach(channelNo, eqNo, DtMt362x);

    ep->activate = mt362xActivate;
    ep->disconnect = mt362xDisconnect;
    ep->func = mt362xFunc;
    ep->io = mt362xIo;
	ep->load = mt362xLoad;
	mp = ep->context;
	if (NULL == mp)
	    {
		mp = calloc(1, sizeof(MtContext));
		if (NULL == mp)
		    {
			fputs("Failed to allocate MT362x context block\n", stderr);
			exit(1);
		    }
		ep->context = mp;
		mp->connectedUnit = -1;
		mp->intMask = 0U;
		mp->intStatus = 0U;
		for (u = 0; u < 16; u++)
			mp->unitExists[u] = FALSE;
		mp->bcdMode = FALSE;
		mp->reverseRead = FALSE;
	    }
	trueUnitNo = unitNo & 07;
	mp->unitExists[trueUnitNo] = TRUE;

    /*
    **  Open the device file.
    */
    if (deviceName == NULL)
		mp->status[trueUnitNo] = 0;
    else
	    {
		mp->fcb[trueUnitNo] = fopen(deviceName, "rb");
		if (NULL == mp->fcb[trueUnitNo])
		    {
			fprintf(stderr, "Failed to open %s\n", deviceName);
			exit(1);
		    }
		mp->status[trueUnitNo] = St362xReady | St362xLoadPoint;
	    }

    /*
    **  Print a friendly message.
    */
    printf("MT362x initialized on channel %o equipment %o unit %o\n",
		channelNo, eqNo, trueUnitNo);
        }
/*--------------------------------------------------------------------------
**  Purpose:        Perform load/unload on 362x tape controller.
**
**  Parameters:     Name        Description.
**
**  Returns:        Nothing.
**
**------------------------------------------------------------------------*/
static void mt362xLoad(Dev3kSlot *up, char *fn)
    {
    MtContext *cc;
    FILE *fcb;
    static char msgBuf[80];
    u8 unitMode = 'r';
    char *p;
    
    if (fn == NULL)
	    {
		opSetMsg ("$UNLOAD NOT SUPPORTED ON MT362x");
        return;
	    }
    
    cc = (MtContext *) (up->context);
    /*
    **  Check if the unit is even configured.
    */
    if (!cc->unitExists[0])
	    {
		opSetMsg ("$UNIT NOT ALLOCATED");
		return;
	    }

    if (cc->fcb[0] != NULL)
	    {
        opSetMsg ("$MTS362x - UNIT NOT UNLOADED");
        return;
	    }
	
	p = strchr (fn, ',');
	if (p != NULL)
	    {
		*p = '\0';
		unitMode = 'w';
	    }
	/*
	**  Open the file in the requested mode.
	*/
	if (unitMode == 'w')
	    {
		fcb = fopen(fn, "r+b");
		if (fcb == NULL)
			fcb = fopen(fn, "w+b");
	    }
	else
		fcb = fopen(fn, "rb");
	if (fcb == NULL)
	    {
		sprintf (msgBuf, "$Open error: %s", strerror (errno));
		opSetMsg(msgBuf);
		return;
	    }
	
	cc->fcb[0] = fcb;
	cc->status[0] |= St362xReady | St362xLoadPoint;
	cc->intStatus |= Int362xReady;
	if ('w' == unitMode)
		cc->status[0] |= St362xWriteEnable;
    
    up->intr = (cc->status[0] & cc->intMask) != 0;
	sprintf (msgBuf, "MT362x loaded with %s", fn);
        opSetMsg (msgBuf);
    }

/*--------------------------------------------------------------------------
**  Purpose:        Execute function code on 362x tape controller.
**
**  Parameters:     Name        Description.
**                  funcCode    function code
**
**  Returns:        FcStatus
**
**------------------------------------------------------------------------*/
static FcStatus mt362xFunc(PpWord funcCode)
        {
	u32 recordHeader, recordTrailer, tripletCount, trp;
    u8 *rawBuffer;
    MtContext *tp;
	PpWord fc;
	FcStatus st;
	int unit;

	tp = (MtContext *)activeUnit->context;

	/* Normally, with real hardware, the 6681 puts the connect code out
	** to all attached 3000 controllers.  Each controller, including the
	** 362x, knows what equipment its own equipment number is from its
	** equipment number switch.  Each controller responds only to connect
	** codes which match its equipment number, and ignore all others.
	**
	** However, in this case, we don't know our own equipment number, but
	** our simulated 6681 converter knows the equipment numbers of all
	** attached 3000 controllers, and sends connect codes only to
	** controllers with matching equipment numbers.  Each controller
	** responds to all connect codes it actually receives, and always
	** connects the specified unit if it's valid.
	**
	** Because valid connect codes for equipment 0 can be the same as
	** valid controller functions, they are only recognized when no unit
	** is presently connected.  Otherwise, the specified function is
	** performed relative to the existing connection.  This means that
	** if this controller is equipment 0, any connected unit must be
	** explicitly disconnected before a new unit can be connected.
	*/

	if (funcCode < Fc362xConnectUnitEqp1)
		fc = funcCode;
	else
		fc = funcCode & Fc362xConnectMask;

	if (-1 == tp->connectedUnit)
	    {
		unit = funcCode & Fc362xUnitMask;
		if (unit < 16 && tp->unitExists[unit] &&
			0 == (tp->status[unit] & St362xBusy))
		    {
			tp->connectedUnit = unit;
			tp->status[unit] &= St362xConnectClr;
			st = FcProcessed;
		    }
		else
			st = FcDeclined;
	    }
	else
		switch (fc)
		    {
		case Fc362xRelease:
			if (St362xReady
				== (tp->status[tp->connectedUnit] & St362xReadyMask))
			    {
				tp->connectedUnit = -1;
				st = FcProcessed;
			    }
			else
				st = FcDeclined;
			break;

		case Fc362xSelectBinary:
			if (St362xReady
				== (tp->status[tp->connectedUnit] & St362xReadyMask))
			    {
				tp->bcdMode = FALSE;
				st = FcProcessed;
			    }
			else
				st = FcDeclined;
			break;

		case Fc362xSelectCoded:
			if (St362xReady
				== (tp->status[tp->connectedUnit] & St362xReadyMask))
			    {
				tp->bcdMode = TRUE;
				st = FcProcessed;
			    }
			else
				st = FcDeclined;
			break;

		case Fc362xSelect556Bpi:
			if (St362xReady
				== (tp->status[tp->connectedUnit] & St362xReadyMask))
			    {
				tp->status[tp->connectedUnit]
					= tp->status[tp->connectedUnit] & St362xNonDensityMask
					| St362xDensity556Bpi;
				st = FcProcessed;
			    }
			else
				st = FcDeclined;
			break;

		case Fc362xSelect200Bpi:
			if (St362xReady
				== (tp->status[tp->connectedUnit] & St362xReadyMask))
			    {
				tp->status[tp->connectedUnit] &= St362xNonDensityMask;
				st = FcProcessed;
			    }
			else
				st = FcDeclined;
			break;

		case Fc362xClear:
			if (St362xReady
				== (tp->status[tp->connectedUnit] & St362xReadyMask))
			    {
				tp->status[tp->connectedUnit]
					= tp->status[tp->connectedUnit] & St362xClearMask
					| St362xEndOfOperation;
				tp->connectedUnit = -1;
				tp->intStatus |= Int362xEndOfOp;
				st = FcProcessed;
			    }
			else
				st = FcDeclined;
			break;

		case Fc362xSelect800Bpi:
			if (St362xReady ==
				(tp->status[tp->connectedUnit] & St362xReadyMask))
			    {
				tp->status[tp->connectedUnit]
					= tp->status[tp->connectedUnit] & St362xNonDensityMask
					| St362xDensity800Bpi;
				st = FcProcessed;
			    }
			else
				st = FcDeclined;
			break;

		case Fc362xRewind:
			if (St362xReady
				== (tp->status[tp->connectedUnit] & St362xReadyMask))
			    {
				fseek(tp->fcb[tp->connectedUnit], 0, SEEK_SET);
				tp->status[tp->connectedUnit]
					= tp->status[tp->connectedUnit] & St362xTpMotionClr
					| St362xLoadPoint | St362xEndOfOperation;
				tp->intStatus |= Int362xEndOfOp | Int362xError;
				st = FcProcessed;
			    }
			else
				st = FcDeclined;
			break;

		case Fc362xRewindUnload:
			if (St362xReady
				== (tp->status[tp->connectedUnit] & St362xReadyMask))
			    {
				mt362xUnload(tp);
				st = FcProcessed;
			    }
			else
				st = FcDeclined;
			break;
			
		case Fc362xBackspace:
			if (St362xReady
				== (tp->status[tp->connectedUnit] & St362xReadyMask))
			    {
				if (tp->reverseRead)
					mt362xSkipForward(tp);
				else
					mt362xSkipBackward(tp);
				st = FcProcessed;
			    }
			else
				st = FcDeclined;
			break;

		case Fc362xSearchFwdFileMark:
			if (St362xReady
				== (tp->status[tp->connectedUnit] & St362xReadyMask))
			    {
				do
					mt362xSkipForward(tp);
				while (0 != tp->byteCount);
				if (0 != (tp->status[tp->connectedUnit] & St362xEndOfTape))
					mt362xUnload(tp);	// ran off end of tape
				st = FcProcessed;
			    }
			else
				st = FcDeclined;
			break;

		case Fc362xSearchBckFileMark:
			if (St362xReady
				== (tp->status[tp->connectedUnit] & St362xReadyMask))
			    {
				do
					mt362xSkipBackward(tp);
				while (0 != tp->byteCount);
				if (0 != (tp->status[tp->connectedUnit] & St362xLoadPoint))
					mt362xUnload(tp);
				st = FcProcessed;
			    }
			else
				st = FcDeclined;
			break;

		case Fc362xWriteFileMark:
			if (St362xWriteReady
				== (tp->status[tp->connectedUnit] & St362xWriteMask))
			    {
				recordHeader = 0;
				tp->status[tp->connectedUnit]
					= tp->status[tp->connectedUnit] & St362xTpMotionClr
					| St362xEndOfOperation;
				if (0 == fwrite(&recordHeader, sizeof(recordHeader),
					1, tp->fcb[tp->connectedUnit]))
				    {
					tp->status[tp->connectedUnit] |= St362xParityError;
					tp->intStatus |= Int362xError;
				    }
				else
				    {
					tp->status[tp->connectedUnit] |= St362xFileMark;
					if (!tp->bcdMode)
						tp->status[tp->connectedUnit] |= St362xParityError;
					tp->intStatus |= Int362xError;
				    }
				tp->intStatus |= Int362xEndOfOp;
				st = FcProcessed;
			    }
			else
				st = FcDeclined;
			break;

		case Fc362xSkipBadSpot:
			if (St362xReady
				== (tp->status[tp->connectedUnit] & St362xReadyMask))
			    {
				tp->status[tp->connectedUnit]
					= tp->status[tp->connectedUnit] & St362xTpMotionClr
					| St362xEndOfOperation;
				tp->intStatus |= Int362xEndOfOp;
				st = FcProcessed;
			    }
			else
				st = FcDeclined;
			break;

		case Fc362xSelectIntReady:
			tp->intMask |= Int362xReady;
			tp->intStatus &= ~Int362xReady;
			st = FcProcessed;
			break;

		case Fc362xReleaseIntReady:
			tp->intMask &= ~Int362xReady;
			tp->intStatus &= ~Int362xReady;
			st = FcProcessed;
			break;

		case Fc362xSelectIntEndOfOp:
			tp->intMask |= Int362xEndOfOp;
			tp->intStatus &= ~Int362xEndOfOp;
			st = FcProcessed;
			break;

		case Fc362xReleaseIntEndOfOp:
			tp->intMask &= ~Int362xEndOfOp;
			tp->intStatus &= ~Int362xEndOfOp;
			st = FcProcessed;
			break;

		case Fc362xSelectIntError:
			tp->intMask |= Int362xError;
			tp->intStatus &= ~Int362xError;
			st = FcProcessed;
			break;

		case Fc362xReleaseIntError:
			tp->intMask &= ~Int362xError;
			tp->intStatus &= ~Int362xError;
			st = FcProcessed;
			break;

		case Fc362xClearReverseRead:
			tp->reverseRead = FALSE;
			st = FcProcessed;
			break;

		case Fc362xSetReverseRead:
			tp->reverseRead = TRUE;
			st = FcProcessed;
			break;

		case Fc6681DevStatusReq:
			/* The tape drive can be statused when it's not ready,
			** but not when it's busy.  Since operating functions
			** complete instantaneously, the only thing which will
			** leave the tape drive busy is a read or write operation.
			** (or a previous uncompleted status request).
			**
			** I suppose there should be some way the drive can be statused,
			** and actually have the busy status returned, but how would
			** mt362xIo() know which was being called for, the equipment
			** status or the data from the tape?
			*/

			if (0 == (tp->status[tp->connectedUnit] & St362xBusy))
			    {
				tp->status[tp->connectedUnit] |= St362xBusy;
				st = FcAccepted;
			    }
			else
				st = FcDeclined;
			break;

		case Fc6681InputToEor:
		case Fc6681Input:
			if (St362xReady
				== (tp->status[tp->connectedUnit] & St362xReadyMask)
				&& 0 == (tp->intStatus & Int362xError))
			    {
				if (tp->reverseRead)
					if (0 ==
						(tp->status[tp->connectedUnit] & St362xLoadPoint))
						mt362xSkipBackward(tp);	//	clears EOT status
					else
						return FcDeclined;
				else
				    {
					if (St362xEndOfTape ==
						(tp->status[tp->connectedUnit] & St362xEndOfTape))
					    {
						mt362xUnload(tp);	// Ran off end of tape
						return FcProcessed;
					    }
				    }
				tp->status[tp->connectedUnit] &= St362xRWclear;
				if (1 == fread(&recordHeader, sizeof(recordHeader),
								1, tp->fcb[tp->connectedUnit]))
				    {
					if (bigEndian)
						tp->byteCount = initConvertEndian(recordHeader);
					else
						tp->byteCount = recordHeader;
					if (0 == tp->byteCount)
					    {
						tp->status[tp->connectedUnit] |=
							St362xFileMark | St362xEndOfOperation;
						if (!tp->bcdMode)
							tp->status[tp->connectedUnit] |=
								St362xParityError;
						tp->intStatus |= Int362xEndOfOp | Int362xError;
						tp->curPpWord = 0;
						st = FcProcessed;
					    }
					else
					    {
						rawBuffer = (u8 *)tp->ioBuffer;
						if (tp->byteCount != fread(rawBuffer, 1,
							tp->byteCount, tp->fcb[tp->connectedUnit]))
						    {
							tp->status[tp->connectedUnit] |=
								St362xParityError;
							tp->intStatus |= Int362xError;
						    }
						if (tp->byteCount > (3*MaxPpBuf)/2)
						    {
							tp->status[tp->connectedUnit] |= St362xLostData;
							tp->byteCount = (3 * MaxPpBuf)/2;
							tp->intStatus |= Int362xError;
						    };
						memset(tp->ioBuffer, 0, MaxPpBuf);
						if (1 != fread(&recordTrailer,
							sizeof(recordTrailer), 1,
							tp->fcb[tp->connectedUnit]))
						    {
							tp->status[tp->connectedUnit] |=
								St362xParityError;
							tp->intStatus |= Int362xError;
						    }
						if (recordHeader != recordTrailer && 0 !=
							(tp->status[tp->connectedUnit] & St362xLostData))
						    {
							tp->status[tp->connectedUnit] |=
								St362xParityError;
							tp->intStatus |= Int362xError;
						    }
						tripletCount = tp->byteCount/3;
						tp->ppWordCount = 2 * tripletCount;
						tp->curPpWord = tp->ppWordCount;
						if (0 != (tp->byteCount % 3))
							tp->ioBuffer[tp->ppWordCount++]
								= rawBuffer[3*tripletCount] << 4 & 07760
								| rawBuffer[3*tripletCount+1] >> 4 & Mask4;
						

						/* Expand the record */

						for (trp = 3*tripletCount - 1; trp >= 0; trp -= 3)
						    {
							tp->ioBuffer[--tp->curPpWord]
								= rawBuffer[trp+1] << 8 & 07400
								| rawBuffer[trp+2] & Mask8;
							tp->ioBuffer[--tp->curPpWord]
								= rawBuffer[trp] << 4 & 07760
								| rawBuffer[trp+1] >> 4 & Mask4;
						    }
						if (tp->reverseRead)
							tp->curPpWord = tp->ppWordCount - 1;
						else
							tp->curPpWord = 0;
						tp->status[tp->connectedUnit] |= St362xBusy;
						st = FcAccepted;
					    }
				    }
				else
				    {
					/* Reached End of Tape
					** This should not be able to happen if Reverse
					** Read is selected.
					*/

					tp->status[tp->connectedUnit] |= 
						St362xEndOfTape | St362xEndOfOperation;
					tp->intStatus |= Int362xEndOfOp | Int362xError;
					st = FcProcessed;
				    }
			    }
			else
				/*  Tape unit was already busy when read was requested */
				st = FcDeclined;
			break;

		case Fc6681Output:
			if (St362xWriteReady ==
				(tp->status[tp->connectedUnit] & St362xWriteMask)
				&& 0 == (tp->intStatus & Int362xError))
				if (St362xEndOfTape ==
					(tp->status[tp->connectedUnit] & St362xEndOfTape))
				    {
					mt362xUnload(tp);	// Ran off end of tape
					st = FcProcessed;
				    }
				else
				    {
					tp->status[tp->connectedUnit] &= St362xRWclear;
					memset(tp->ioBuffer, 0, MaxPpBuf);
					tp->curPpWord = 0;
					tp->status[tp->connectedUnit] |= St362xBusy;
					st = FcAccepted;
				    }
			else
				st = FcDeclined;
			break;

		case Fc6681MasterClear:
			tp->connectedUnit = -1;
			tp->bcdMode = FALSE;
			tp->intMask = 0;
			tp->intStatus = 0;
			for (unit = 0; unit < 16; unit++)
				if (tp->unitExists[unit])
					tp->status[unit] &= St362xMstrClrMask;
			st = FcProcessed;
			break;

		case Fc362xConnectUnitEqp1:
		case Fc362xConnectUnitEqp2:
		case Fc362xConnectUnitEqp3:
		case Fc362xConnectUnitEqp4:
		case Fc362xConnectUnitEqp5:
		case Fc362xConnectUnitEqp6:
		case Fc362xConnectUnitEqp7:
			tp->connectedUnit = -1;
			unit = funcCode & Fc362xUnitMask;
			if (unit < 16 && tp->unitExists[unit] &&
				0 == (tp->status[unit] & St362xBusy))
			    {
				tp->connectedUnit = unit;
				tp->status[tp->connectedUnit] &= St362xConnectClr;
				st = FcProcessed;
			    }
			else
				st = FcDeclined;
			break;

		default:
			st = FcDeclined;
			break;
		    }
		if (FcDeclined != st)
			activeUnit->fcode = fc;
		activeUnit->intr = (tp->intMask & tp->intStatus) != 0;
		return st;
    }

/*--------------------------------------------------------------------------
**  Purpose:        Perform I/O on the 362x Tape Controller.
**
**  Parameters:     Name        Description.
**
**  Returns:        Nothing.
**
**------------------------------------------------------------------------*/
static void mt362xIo(void)
    {
    MtContext *tp;
	PpWord ext1, ext2, int1, int2;

	tp = (MtContext *)activeUnit->context;

	switch (activeDevice->fcode)
	    {
	case Fc6681DevStatusReq:
		if (!activeChannel->full)
		    {
			tp->status[tp->connectedUnit] &= St362xClearBusy;
			activeChannel->data = tp->status[tp->connectedUnit];
			activeChannel->full = TRUE;
			tp->status[tp->connectedUnit] |= St362xEndOfOperation;
			tp->intStatus |= Int362xEndOfOp;
		    }
		break;

	case Fc6681InputToEor:
		if (!activeChannel->full)
			if (tp->reverseRead)
			    {
				if (tp->curPpWord <= 0)
				    {
					activeChannel->discAfterInput = TRUE;
					tp->status[tp->connectedUnit]
						= tp->status[tp->connectedUnit] & St362xClearBusy
						| St362xEndOfOperation;
					tp->intStatus |= Int362xEndOfOp;
				    }
			    }
			else
				if (tp->ppWordCount-1 >= tp->curPpWord)
				    {
					activeChannel->discAfterInput = TRUE;
					tp->status[tp->connectedUnit]
						= tp->status[tp->connectedUnit] & St362xClearBusy
						| St362xEndOfOperation;
					tp->intStatus |= Int362xEndOfOp;
				    }

		// Fall Through

	case Fc6681Input:
		if (!activeChannel->full &&
			0 == (tp->status[tp->connectedUnit] & St362xLostData))
		    {
			if (tp->bcdMode)
			    {
				ext1 = tp->ioBuffer[tp->curPpWord] >> 6 & Mask6;
				ext2 = tp->ioBuffer[tp->curPpWord] & Mask6;
				int1 = extBcdToIntBcd[ext1];
				int2 = extBcdToIntBcd[ext2];
				activeChannel->data = int1 << 6 | int2;
			    }
			else
				activeChannel->data = tp->ioBuffer[tp->curPpWord];
			activeChannel->full = TRUE;
			if (tp->reverseRead)
				tp->curPpWord -= 1;
			else
				tp->curPpWord += 1;
		    }
		break;

	case Fc6681Output:
		if (activeChannel->full &&
			0 == (tp->status[tp->connectedUnit] & St362xLostData))
		    {
			if (tp->bcdMode)
			    {
				int1 = activeChannel->data >> 6 & Mask6;
				int2 = activeChannel->data & Mask6;
				ext1 = intBcdToExtBcd[int1];
				ext2 = intBcdToExtBcd[int2];
				tp->ioBuffer[tp->curPpWord++] = ext1 << 6 | ext2;
			    }
			else
				tp->ioBuffer[tp->curPpWord++] = activeChannel->data;
			activeChannel->full = FALSE;
			if (tp->curPpWord >= tp->ppWordCount)
				tp->status[tp->connectedUnit] |= St362xLostData;
		    }
		
		//	Fall Through

	default:	// No Action

		break;
	    }
	activeUnit->intr = (tp->intStatus & tp->intMask) != 0;
    }

/*--------------------------------------------------------------------------
**  Purpose:        Handle channel activation.
**
**  Parameters:     Name        Description.
**
**  Returns:        Nothing.
**
**------------------------------------------------------------------------*/
static void mt362xActivate(void)
    {
    MtContext *tp;

	tp = (MtContext *)activeUnit->context;
	activeUnit->intr = (tp->intStatus & tp->intMask) != 0;
    }

/*--------------------------------------------------------------------------
**  Purpose:        Handle disconnecting of channel.
**
**  Parameters:     Name        Description.
**
**  Returns:        Nothing.
**
**------------------------------------------------------------------------*/
static void mt362xDisconnect(void)
    {
    MtContext *tp;
	u8 *rawBuffer;
	u32 byteCount = 0, controlWord, pairCount;

	tp = (MtContext *)activeUnit->context;
	switch (activeDevice->fcode)
	    {
	case Fc6681Output:
		tp->ppWordCount = tp->curPpWord;
		if (tp->ppWordCount != 0 && St362xWriteReady ==
			(tp->status[tp->connectedUnit] & St362xWriteMask))
		    {
			pairCount = tp->ppWordCount/2;
			rawBuffer = (u8 *)tp->ioBuffer;
			for (tp->curPpWord = 0; tp->curPpWord < 2*pairCount;
				tp->curPpWord += 2)
			    {
				rawBuffer[byteCount++]
					= tp->ioBuffer[tp->curPpWord] >> 4 & Mask8;
				rawBuffer[byteCount++]
					= (tp->ioBuffer[tp->curPpWord] &  Mask4) << 4
					| tp->ioBuffer[tp->curPpWord+1] >> 4 & Mask4;
				rawBuffer[byteCount++]
					= tp->ioBuffer[tp->curPpWord+1] & Mask8;
			    }
			if (0 != tp->ppWordCount % 2)
			    {
				rawBuffer[byteCount++]
					= tp->ioBuffer[tp->ppWordCount - 1] >> 4 & Mask8;
				rawBuffer[byteCount++]
					= (tp->ioBuffer[tp->ppWordCount-1] & Mask4) << 4;
			    }
			if (bigEndian)
				controlWord = initConvertEndian(byteCount);
			else
				controlWord = byteCount;
			if (1 != fwrite(&controlWord, sizeof(controlWord), 1,
				tp->fcb[tp->connectedUnit]))
			    {
				tp->status[tp->connectedUnit] |= St362xParityError;
				tp->intStatus |= Int362xError;
			    }
			if (byteCount != fwrite(rawBuffer, 1, byteCount,
				tp->fcb[tp->connectedUnit]))
			    {
				tp->status[tp->connectedUnit] |= St362xParityError;
				tp->intStatus |= Int362xError;
			    }
			if (1 != fwrite(&controlWord, sizeof(controlWord),
				1, tp->fcb[tp->connectedUnit]))
			    {
				tp->status[tp->connectedUnit] |= St362xParityError;
				tp->intStatus |= Int362xError;
			    }
		    }

			// Fall Through

		case Fc6681Input:
		case Fc6681InputToEor:
			tp->status[tp->connectedUnit] |= St362xEndOfOperation;
			tp->intStatus |= Int362xEndOfOp;

			// Fall Through

		default:
			break;

	    }

	activeUnit->intr = (tp->intStatus & tp->intMask) != 0;
    }
/*--------------------------------------------------------------------------
**  Purpose:        Skip one record in the backward direction.
**
**  Parameters:     Name        Description.
**
**  Returns:        Nothing.
**
**------------------------------------------------------------------------*/
static void mt362xSkipBackward(MtContext *tp)
    {
	u32 controlWord;

	if (St362xLoadPoint == (tp->status[tp->connectedUnit] & St362xEndOfTape))
		mt362xUnload(tp);	// Skipped back past beginning of tape
	else
	    {
		tp->status[tp->connectedUnit] &= St362xTpMotionClr;
		tp->byteCount = 0;
		if (0 == fseek(tp->fcb[tp->connectedUnit],
			-(int)sizeof(controlWord),	SEEK_CUR))
		    {
			fread(&controlWord, sizeof(controlWord), 1,
				tp->fcb[tp->connectedUnit]);
			if (bigEndian)
				tp->byteCount = initConvertEndian(controlWord);
			else
				tp->byteCount = controlWord;
			if (0 == tp->byteCount)
			    {
				tp->status[tp->connectedUnit] |= St362xFileMark;
				if (!tp->bcdMode)
					tp->status[tp->connectedUnit] |= St362xParityError;
				tp->intStatus |= Int362xError;
			    }
			else
				if (0 != fseek(tp->fcb[tp->connectedUnit],
					-(int)tp->byteCount-2*(int)sizeof(controlWord),
					SEEK_CUR))
				    {
					/* error - record not all there */
					tp->status[tp->connectedUnit] |= St362xParityError;
					tp->intStatus |= Int362xError;
				    }
		    }
		else
		    {
			fseek(tp->fcb[tp->connectedUnit], 0, SEEK_SET);
			tp->status[tp->connectedUnit] |= St362xLoadPoint;
			tp->intStatus |= Int362xError;
		    }
		tp->status[tp->connectedUnit] |= St362xEndOfOperation;
		tp->intStatus |= Int362xError;
	    }

    }
/*--------------------------------------------------------------------------
**  Purpose:        Skip one record in the forward direction.
**
**  Parameters:     Name        Description.
**
**  Returns:        Nothing.
**
**------------------------------------------------------------------------*/
static void mt362xSkipForward(MtContext *tp)
    {
	u32 controlWord;

	if (St362xEndOfTape == (tp->status[tp->connectedUnit] & St362xEndOfTape))
        {
		mt362xUnload(tp);	// Skipped forward off end of tape
        }
	else
	    {
		tp->status[tp->connectedUnit] &= St362xTpMotionClr;
		tp->byteCount = 0;
		if (1 == fread(&controlWord, sizeof(controlWord), 1,
			tp->fcb[tp->connectedUnit]))
		    {
			if (bigEndian)
				tp->byteCount = initConvertEndian(controlWord);
			else
				tp->byteCount = controlWord;
			if (0 == tp->byteCount)
			    {
				tp->status[tp->connectedUnit] |= St362xFileMark;
				if (!tp->bcdMode)
					tp->status[tp->connectedUnit] |= St362xParityError;
				tp->intStatus |= Int362xError;
			    }
			else
				if (0 != fseek(tp->fcb[tp->connectedUnit],
					tp->byteCount + sizeof(controlWord), SEEK_CUR))
				    {
					/* record not all there - error */
					tp->status[tp->connectedUnit] |= St362xParityError;
					tp->intStatus |= Int362xError;
				    }
		    }
		else
		    {
			tp->status[tp->connectedUnit] |= St362xEndOfTape;
			tp->intStatus |= Int362xError;
		    }
		tp->status[tp->connectedUnit] |= St362xEndOfOperation;
		tp->intStatus |= Int362xEndOfOp;
	    }
    }
/*--------------------------------------------------------------------------
**  Purpose:        Handle unloading of the connected tape unit.
**
**  Parameters:     Name        Description.
**
**  Returns:        Nothing.
**
**------------------------------------------------------------------------*/
static void mt362xUnload(MtContext *tp)
    {
	fclose(tp->fcb[tp->connectedUnit]);
	tp->fcb[tp->connectedUnit] = NULL;
	tp->status[tp->connectedUnit]
		= tp->status[tp->connectedUnit] & St362xDensityParity
		| St362xEndOfOperation;
	tp->intStatus |= Int362xEndOfOp | Int362xError;
    }

/*---------------------------  End Of File  ------------------------------*/

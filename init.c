/*--------------------------------------------------------------------------
**
**  Copyright (c) 2003-2011, Tom Hunter
**
**  Name: init.c
**
**  Description:
**      Perform reading and validation of startup file and use configured
**      values to startup emulation.
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
#include <string.h>
#include <ctype.h>
#include <sys/stat.h>
#include "const.h"
#include "types.h"
#include "proto.h"

/*
**  -----------------
**  Private Constants
**  -----------------
*/
#define MaxLine                 512

/*
**  -----------------------
**  Private Macro Functions
**  -----------------------
*/
#define isoctal(c) ((c) >= '0' && (c) <= '7')

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
static void initCyber(char *config);
static void initEquipment(void);
static void initDeadstart(void);
static bool initOpenSection(char *name);
static char *initGetNextLine(void);
static bool initGetOctal(char *entry, int defValue, long *value);
static bool initGetInteger(char *entry, int defValue, long *value);
static bool initGetString(char *entry, char *defString, char *str, int strLen);

/*
**  ----------------
**  Public Variables
**  ----------------
*/
bool bigEndian;
extern u16 deadstartPanel[];
extern u8 deadstartCount;
ModelFeatures features;
ModelType modelType;
char persistDir[256];

/*
**  -----------------
**  Private Variables
**  -----------------
*/
static FILE *fcb;
static long sectionStart;
static char *startupFile = "cyber.ini";
static char deadstart[40];
static char equipment[40];
static long chCount;
static union
    {
    u32 number;
    u8 bytes[4];
    } endianCheck;

static ModelFeatures features6400 = (IsSeries6x00);
static ModelFeatures featuresCyber73 = (IsSeries70 | HasInterlockReg | HasCMU);
static ModelFeatures featuresCyber173 =
    (IsSeries170 | HasStatusAndControlReg | HasCMU);
static ModelFeatures featuresCyber175 =
    (IsSeries170 | HasStatusAndControlReg | HasInstructionStack | HasIStackPrefetch | Has175Float);
static ModelFeatures featuresCyber840A =
    (  IsSeries800 | HasNoCmWrap | HasFullRTC | HasTwoPortMux | HasMaintenanceChannel | HasCMU | HasChannelFlag
     | HasErrorFlag | HasRelocationRegLong | HasMicrosecondClock | HasInstructionStack | HasIStackPrefetch);
static ModelFeatures featuresCyber865 =
    (  IsSeries800 | HasNoCmWrap | HasFullRTC | HasTwoPortMux | HasStatusAndControlReg
     | HasRelocationRegShort | HasMicrosecondClock | HasInstructionStack | HasIStackPrefetch | Has175Float);

/*
**--------------------------------------------------------------------------
**
**  Public Functions
**
**--------------------------------------------------------------------------
*/

/*--------------------------------------------------------------------------
**  Purpose:        Read and process startup file.
**
**  Parameters:     Name        Description.
**                  config      name of the section to run
**
**  Returns:        Nothing.
**
**------------------------------------------------------------------------*/
void initStartup(char *config)
    {
    /*
    **  Open startup file.
    */
    fcb = fopen(startupFile, "rb");
    if (fcb == NULL)
        {
        perror(startupFile);
        exit(1);
        }

    /*
    **  Determine endianness of the host.
    */
    endianCheck.bytes[0] = 0;
    endianCheck.bytes[1] = 0;
    endianCheck.bytes[2] = 0;
    endianCheck.bytes[3] = 1;
    bigEndian = endianCheck.number == 1;

    /*
    **  Read and process cyber.ini file.
    */
    printf("\n%s\n", DtCyberVersion " - " DtCyberCopyright);
    printf("%s\n\n", DtCyberLicense);
    printf("Starting initialisation\n");

    initCyber(config);
    initDeadstart();
    initEquipment();

    if ((features & HasMaintenanceChannel) != 0)
        {
        mchInit(0, 0, ChMaintenance, NULL);
        }
    }

/*--------------------------------------------------------------------------
**  Purpose:        Convert endian-ness of 32 bit value,
**
**  Parameters:     Name        Description.
**
**  Returns:        Converted value.
**
**------------------------------------------------------------------------*/
u32 initConvertEndian(u32 value)
    {
    u32 result;

    result  = (value & 0xff000000) >> 24;
    result |= (value & 0x00ff0000) >>  8;
    result |= (value & 0x0000ff00) <<  8;
    result |= (value & 0x000000ff) << 24;

    return(result);
    }

/*
**--------------------------------------------------------------------------
**
**  Private Functions
**
**--------------------------------------------------------------------------
*/

/*--------------------------------------------------------------------------
**  Purpose:        Read and process [cyber] startup file section.
**
**  Parameters:     Name        Description.
**                  config      name of the section to run
**
**  Returns:        Nothing.
**
**------------------------------------------------------------------------*/
static void initCyber(char *config)
    {
    char model[40];
    char dummy[256];
    long memory;
    long ecsBanks;
    long esmBanks;
    long enableCejMej;
    long clockIncrement;
    long pps;
    long mask;
    long port;
    long conns;
    long setMHz;

    if (!initOpenSection(config))
        {
        fprintf(stderr, "Required section [%s] not found in %s\n", config, startupFile);
        exit(1);
        }

    /*
    **  Check for obsolete keywords and abort if found.
    */
    if (initGetOctal("channels", 020, &chCount))
        {
        fprintf(stderr, "Entry 'channels' obsolete in section [cyber] in %s,\n", startupFile);
        fprintf(stderr, "channel count is determined from PP count.\n");
        exit(1);
        }

    if (initGetString("cmFile", "", dummy, sizeof(dummy)))
        {
        fprintf(stderr, "Entry 'cmFile' obsolete in section [cyber] in %s,\n", startupFile);
        fprintf(stderr, "please use 'persistDir' instead.\n");
        exit(1);
        }

    if (initGetString("ecsFile", "", dummy, sizeof(dummy)))
        {
        fprintf(stderr, "Entry 'ecsFile' obsolete in section [cyber] in %s,\n", startupFile);
        fprintf(stderr, "please use 'persistDir' instead.\n");
        exit(1);
        }

    /*
    **  Determine mainframe model and setup feature structure.
    */
    (void)initGetString("model", "6400", model, sizeof(model));

    if (stricmp(model, "6400") == 0)
        {
        modelType = Model6400;
        features = features6400;
        }
    else if (stricmp(model, "CYBER73") == 0)
        {
        modelType = ModelCyber73;
        features = featuresCyber73;
        }
    else if (stricmp(model, "CYBER173") == 0)
        {
        modelType = ModelCyber173;
        features = featuresCyber173;
        }
    else if (stricmp(model, "CYBER175") == 0)
        {
        modelType = ModelCyber175;
        features = featuresCyber175;
        }
    else if (stricmp(model, "CYBER840A") == 0)
        {
        modelType = ModelCyber840A;
        features = featuresCyber840A;
        }
    else if (stricmp(model, "CYBER865") == 0)
        {
        modelType = ModelCyber865;
        features = featuresCyber865;
        }
    else
        {
        fprintf(stderr, "Entry 'model' specified unsupported mainframe %s in section [%s] in %s\n", model, config, startupFile);
        exit(1);
        }

    (void)initGetInteger("CEJ/MEJ", 1, &enableCejMej);
    if (enableCejMej == 0)
        {
        features |= HasNoCejMej;
        }

    /*
    **  Determine CM size and ECS banks.
    */
    (void)initGetOctal("memory", 01000000, &memory);
    if (memory < 040000)
        {
        fprintf(stderr, "Entry 'memory' less than 40000B in section [%s] in %s\n", config, startupFile);
        exit(1);
        }

    if (modelType == ModelCyber865)
        {
        if (   memory != 01000000
            && memory != 02000000
            && memory != 03000000
            && memory != 04000000)
            {
            fprintf(stderr, "Cyber 170-865 memory must be configured in 262K increments in section [%s] in %s\n", config, startupFile);
            exit(1);
            }
        }

    (void)initGetInteger("ecsbanks", 0, &ecsBanks);
    switch(ecsBanks)
        {
    case 0:
    case 1:
    case 2:
    case 4:
    case 8:
    case 16:
        break;

    default:
        fprintf(stderr, "Entry 'ecsbanks' invalid in section [%s] in %s - correct values are 0, 1, 2, 4, 8 or 16\n", config, startupFile);
        exit(1);
        }

    (void)initGetInteger("esmbanks", 0, &esmBanks);
    switch(esmBanks)
        {
    case 0:
    case 1:
    case 2:
    case 4:
    case 8:
    case 16:
        break;

    default:
        fprintf(stderr, "Entry 'esmbanks' invalid in section [%s] in %s - correct values are 0, 1, 2, 4, 8 or 16\n", config, startupFile);
        exit(1);
        }

    if (ecsBanks != 0 && esmBanks != 0)
        {
        fprintf(stderr, "You can't have both 'ecsbanks' and 'esmbanks' in section [%s] in %s\n", config, startupFile);
        exit(1);
        }

    /*
    **  Determine where to persist data between emulator invocations
    **  and check if directory exists.
    */
    if (initGetString("persistDir", "", persistDir, sizeof(persistDir)))
        {
        struct stat s;
        if (stat(persistDir, &s) != 0)
            {
            fprintf(stderr, "Entry 'persistDir' in section [cyber] in %s\n", startupFile);
            fprintf(stderr, "specifies non-existing directory '%s'.\n", persistDir);
            exit(1);
            }

        if ((s.st_mode & S_IFDIR) == 0)
            {
            fprintf(stderr, "Entry 'persistDir' in section [cyber] in %s\n", startupFile);
            fprintf(stderr, "'%s' is not a directory.\n", persistDir);
            exit(1);
            }
        }

    /*
    **  Initialise CPU.
    */
    cpuInit(model, memory, ecsBanks + esmBanks, ecsBanks != 0 ? ECS : ESM);

    /*
    **  Determine number of PPs and initialise PP subsystem.
    */
    (void)initGetOctal("pps", 012, &pps);
    if (pps != 012 && pps != 024)
        {
        fprintf(stderr, "Entry 'pps' invalid in section [cyber] in %s - supported values are 12 or 24\n", startupFile);
        exit(1);
        }

    ppInit((u8)pps);

    /*
    **  Calculate number of channels and initialise channel subsystem.
    */
    if (pps == 012)
        {
        chCount = 020;
        }
    else
        {
        chCount = 040;
        }

    channelInit((u8)chCount);

    /*
    **  Get active deadstart switch section name.
    */
    if (!initGetString("deadstart", "", deadstart, sizeof(deadstart)))
        {
        fprintf(stderr, "Required entry 'deadstart' in section [cyber] not found in %s\n", startupFile);
        exit(1);
        }

    /*
    **  Get cycle counter speed in MHz.
    */
    (void)initGetInteger("setMhz", 0, &setMHz);

    /*
    **  Get clock increment value and initialise clock.
    */
    (void)initGetInteger("clock", 0, &clockIncrement);

    rtcInit((u8)clockIncrement, setMHz);

    /*
    **  Initialise optional Interlock Register on channel 15.
    */
    if ((features & HasInterlockReg) != 0)
        {
        if (pps == 012)
            {
            ilrInit(64);
            }
        else
            {
            ilrInit(128);
            }
        }

    /*
    **  Initialise optional Status/Control Register on channel 16.
    */
    if ((features & HasStatusAndControlReg) != 0)
        {
        scrInit(ChStatusAndControl);
        if (pps == 024)
            {
            scrInit(ChStatusAndControl + 020);
            }
        }

    /*
    **  Get active equipment section name.
    */
    if (!initGetString("equipment", "", equipment, sizeof(equipment)))
        {
        fprintf(stderr, "Required entry 'equipment' in section [cyber] not found in %s\n", startupFile);
        exit(1);
        }

    /*
    **  Get optional trace mask. If not specified, use compile time value.
    */
    if (initGetOctal("trace", 0, &mask))
        {
        traceMask = (u32)mask;
        }

    /*
    **  Get optional Telnet port number. If not specified, use default value.
    */
    initGetInteger("telnetport", 5000, &port);
    mux6676TelnetPort = (u16)port;

    /*
    **  Get optional max Telnet connections. If not specified, use default value.
    */
    initGetInteger("telnetconns", 4, &conns);
    mux6676TelnetConns = (u16)conns;
    }

/*--------------------------------------------------------------------------
**  Purpose:        Read and process equipment definitions.
**
**  Parameters:     Name        Description.
**
**  Returns:        Nothing.
**
**------------------------------------------------------------------------*/
static void initEquipment(void)
    {
    char *line;
    char *token;
    char *deviceName;
    int eqNo;
    int unitNo;
    int channelNo;
    u8 deviceIndex;
    int lineNo;


    if (!initOpenSection(equipment))
        {
        fprintf(stderr, "Required section [%s] not found in %s\n", equipment, startupFile);
        exit(1);
        }

    /*
    **  Process all equipment entries.
    */
    lineNo = -1;
    while  ((line = initGetNextLine()) != NULL)
        {
        lineNo += 1;

        /*
        **  Parse device type.
        */
        token = strtok(line, ",");
        if (token == NULL || strlen(token) < 2)
            {
            fprintf(stderr, "Section [%s], relative line %d, invalid device type %s in %s\n",
                equipment, lineNo, token, startupFile);
            exit(1);
            }

        for (deviceIndex = 0; deviceIndex < deviceCount; deviceIndex++)
            {
            if (strcmp(token, deviceDesc[deviceIndex].id) == 0)
                {
                break;
                }
            }

        if (deviceIndex == deviceCount)
            {
            fprintf(stderr, "Section [%s], relative line %d, unknown device %s in %s\n",
                equipment, lineNo, token, startupFile);
            exit(1);
            }

        /*
        **  Parse equipment number.
        */
        token = strtok(NULL, ",");
        if (token == NULL || strlen(token) != 1 || !isoctal(token[0]))
            {
            fprintf(stderr, "Section [%s], relative line %d, invalid equipment no %s in %s\n",
                equipment, lineNo, token, startupFile);
            exit(1);
            }

        eqNo = strtol(token, NULL, 8);

        /*
        **  Parse unit number.
        */
        token = strtok(NULL, ",");
        if (token == NULL || !isoctal(token[0]))
            {
            fprintf(stderr, "Section [%s], relative line %d, invalid unit count %s in %s\n",
                equipment, lineNo, token, startupFile);
            exit(1);
            }

        unitNo = strtol(token, NULL, 8);

        /*
        **  Parse channel number.
        */
        token = strtok(NULL, ", ");
        if (token == NULL || strlen(token) != 2 || !isoctal(token[0]) || !isoctal(token[1]))
            {
            fprintf(stderr, "Section [%s], relative line %d, invalid channel no %s in %s\n",
                equipment, lineNo, token, startupFile);
            exit(1);
            }

        channelNo = strtol(token, NULL, 8);

        if (channelNo < 0 || channelNo >= chCount)
            {
            fprintf(stderr, "Section [%s], relative line %d, channel no %s not permitted in %s\n",
                equipment, lineNo, token, startupFile);
            exit(1);
            }

        /*
        **  Parse optional file name.
        */
        deviceName = strtok(NULL, " ");

        /*
        **  Initialise device.
        */
        deviceDesc[deviceIndex].init((u8)eqNo, (u8)unitNo, (u8)channelNo, deviceName);
        }
    }

/*--------------------------------------------------------------------------
**  Purpose:        Read and process deadstart panel settings.
**
**  Parameters:     Name        Description.
**
**  Returns:        Nothing.
**
**------------------------------------------------------------------------*/
static void initDeadstart(void)
    {
    char *line;
    char *token;
    u8 lineNo;


    if (!initOpenSection(deadstart))
        {
        fprintf(stderr, "Required section [%s] not found in %s\n", deadstart, startupFile);
        exit(1);
        }

    /*
    **  Process all deadstart panel switches.
    */
    lineNo = 0;
    while  ((line = initGetNextLine()) != NULL && lineNo < MaxDeadStart)
        {
        /*
        **  Parse switch settings.
        */
        token = strtok(line, " ;\n");
        if (   token == NULL || strlen(token) != 4
            || !isoctal(token[0]) || !isoctal(token[1])
            || !isoctal(token[2]) || !isoctal(token[3]))
            {
            fprintf(stderr, "Section [%s], relative line %d, invalid deadstart setting %s in %s\n",
                deadstart, lineNo, token, startupFile);
            exit(1);
            }

        deadstartPanel[lineNo++] = (u16)strtol(token, NULL, 8);
        }

    deadstartCount = lineNo + 1;
    }

/*--------------------------------------------------------------------------
**  Purpose:        Locate section header and remember the start of data.
**
**  Parameters:     Name        Description.
**                  name        section name
**
**  Returns:        TRUE if section was found, FALSE otherwise.
**
**------------------------------------------------------------------------*/
static bool initOpenSection(char *name)
    {
    char lineBuffer[MaxLine];
    char section[40];
    u8 sectionLength = strlen(name) + 2;

    /*
    **  Build section label.
    */
    strcpy(section, "[");
    strcat(section, name);
    strcat(section, "]");

    /*
    **  Reset to beginning.
    */
    fseek(fcb, 0, SEEK_SET);

    /*
    **  Try to find section header.
    */
    do
        {
        if (fgets(lineBuffer, MaxLine, fcb) == NULL)
            {
            /*
            **  End-of-file - return failure.
            */
            return(FALSE);
            }
        } while (strncmp(lineBuffer, section, sectionLength) != 0);

    /*
    **  Remember start of section and return success.
    */
    sectionStart = ftell(fcb);
    return(TRUE);
    }

/*--------------------------------------------------------------------------
**  Purpose:        Return next non-blank line in section
**
**  Parameters:     Name        Description.
**
**  Returns:        Pointer to line buffer
**
**------------------------------------------------------------------------*/
static char *initGetNextLine(void)
    {
    static char lineBuffer[MaxLine];
    char *cp;
    bool blank;

    /*
    **  Get next lineBuffer.
    */
    do
        {
        if (   fgets(lineBuffer, MaxLine, fcb) == NULL
            || lineBuffer[0] == '[')
            {
            /*
            **  End-of-file or end-of-section - return failure.
            */
            return(NULL);
            }

        /*
        **  Determine if this line consists only of whitespace or comment and
        **  replace all whitespace by proper space.
        */
        blank = TRUE;
        for (cp = lineBuffer; *cp != 0; cp++)
            {
            if (blank && *cp == ';')
                {
                break;
                }

            if (isspace(*cp))
                {
                *cp = ' ';
                }
            else
                {
                blank = FALSE;
                }
            }

        } while (blank);

    /*
    **  Found a non-blank line - return to caller.
    */
    return(lineBuffer);
    }

/*--------------------------------------------------------------------------
**  Purpose:        Locate octal entry within section and return value.
**
**  Parameters:     Name        Description.
**                  entry       entry name
**                  defValue    default value
**                  value       pointer to return value
**
**  Returns:        TRUE if entry was found, FALSE otherwise.
**
**------------------------------------------------------------------------*/
static bool initGetOctal(char *entry, int defValue, long *value)
    {
    char buffer[40];

    if (   !initGetString(entry, "", buffer, sizeof(buffer))
        || buffer[0] < '0'
        || buffer[0] > '7')
        {
        /*
        **  Return default value.
        */
        *value = defValue;
        return(FALSE);
        }

    /*
    **  Convert octal string to value.
    */
    *value = strtol(buffer, NULL, 8);

    return(TRUE);
    }

/*--------------------------------------------------------------------------
**  Purpose:        Locate integer entry within section and return value.
**
**  Parameters:     Name        Description.
**                  entry       entry name
**                  defValue    default value
**                  value       pointer to return value
**
**  Returns:        TRUE if entry was found, FALSE otherwise.
**
**------------------------------------------------------------------------*/
static bool initGetInteger(char *entry, int defValue, long *value)
    {
    char buffer[40];

    if (   !initGetString(entry, "", buffer, sizeof(buffer))
        || buffer[0] < '0'
        || buffer[0] > '9')
        {
        /*
        **  Return default value.
        */
        *value = defValue;
        return(FALSE);
        }

    /*
    **  Convert integer string to value.
    */
    *value = strtol(buffer, NULL, 10);

    return(TRUE);
    }

/*--------------------------------------------------------------------------
**  Purpose:        Locate string entry within section and return string
**
**  Parameters:     Name        Description.
**                  entry       entry name
**                  defString   default string
**                  str         pointer to string buffer (return value)
**                  strLen      length of string buffer
**
**  Returns:        TRUE if entry was found, FALSE otherwise.
**
**------------------------------------------------------------------------*/
static bool initGetString(char *entry, char *defString, char *str, int strLen)
    {
    u8 entryLength = strlen(entry);
    char *line;
    char *pos;

    /*
    **  Leave room for zero terminator.
    */
    strLen -= 1;

    /*
    **  Reset to begin of section.
    */
    fseek(fcb, sectionStart, SEEK_SET);

    /*
    **  Try to find entry.
    */
    do
        {
        if ((line = initGetNextLine()) == NULL)
            {
            /*
            **  Copy return value.
            */
            strncpy(str, defString, strLen);

            /*
            **  End-of-file or end-of-section - return failure.
            */
            return(FALSE);
            }
        } while (strncmp(line, entry, entryLength) != 0);

    /*
    **  Cut off any trailing comments.
    */
    pos = strchr(line, ';');
    if (pos != NULL)
        {
        *pos = 0;
        }

    /*
    **  Cut off any trailing whitespace.
    */
    pos = line + strlen(line) - 1;
    while (pos > line && isspace(*pos))
        {
        *pos-- = 0;
        }

    /*
    **  Locate start of value.
    */
    pos = strchr(line, '=');
    if (pos == NULL)
        {
        if (defString != NULL)
            {
            strncpy(str, defString, strLen);
            }

        /*
        **  No value specified.
        */
        return(FALSE);
        }

    /*
    **  Return value and success.
    */
    strncpy(str, pos + 1, strLen);
    return(TRUE);
    }

/*---------------------------  End Of File  ------------------------------*/



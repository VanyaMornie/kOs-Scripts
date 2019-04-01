// Boot script with basic functions.

CORE:PART:GETMODULE("kOSProcessor"):DOEVENT("Open Terminal").

LOCK mTime TO MISSIONTIME.
SET maxLinesToPrint TO 24. // Max # of lines in scrolling list
SET listLineStart TO 16. // First line for print scrolling list

FUNCTION NOTIFY {
  PARAMETER alertString.
  HUDTEXT("kOS: " + alertString, 5, 2, 50, WHITE, false).
}

//Scrolling print setup
SET printList TO LIST().
FUNCTION scrollPrint {
    DECLARE PARAMETER nextPrint.
    printList:ADD(nextPrint).
    UNTIL printList:LENGTH <= maxLinesToPrint {printList:REMOVE(0).}.
    LOCAL currentLine IS listLineStart.
    FOR printLine in printList {
        PRINT "                                                 " AT (0,currentLine).
        PRINT printLine AT (0,currentLine).
        SET currentLine TO currentLine+1.
    }.
}.

//File operations
FUNCTION REQUIRE {
  PARAMETER scrReqName.
  IF NOT HAS_FILE(scrReqName, 1) { DOWNLOAD(scrReqName). }
  RUNPATH(scrReqName).
}

FUNCTION DOWNLOAD {
	PARAMETER scrDwnName.
	CD("1:/").
	IF EXISTS(scrDwnName) {DELETEPATH(scrDwnName).}
	ELSE {COPYPATH("0:/"+scrDwnName,"1:/"+scrDwnName).}
}

FUNCTION HAS_FILE {
  PARAMETER scrName.
  PARAMETER vol.
  
  SWITCH TO vol.
  IF EXISTS(scrName) {
	SWITCH TO 1.
	RETURN TRUE.
	}
  SWITCH TO 1.
  RETURN FALSE.
}

// THE ACTUAL BOOTUP PROCESS
SET updateScript TO SHIP:NAME + ".update.ks".
// If we have a connection, see if there are new instructions. If so, download
// and run them.
IF SHIP:CONNECTION:ISCONNECTED OR SHIP:STATUS = "PRELAUNCH"{
	scrollPrint("T+"+ROUND(MET,1)+" Checking for updated instructions").
	IF HAS_FILE(updateScript, 0) {
	scrollPrint("T+"+ROUND(MET,1)+" New instructions located - downloading").
	DOWNLOAD(updateScript).
    RUNPATH(updateScript).
	}
}
  // If a startup.ks file exists on the disk, run that.
IF HAS_FILE("startup.ks", 1) {
	RUNPATH(startup).
	}
	// ELSE {
	// WAIT UNTIL SHIP:CONNECTION:ISCONNECTED.
	// WAIT 10.	// Avoid thrashing the CPU (when no startup.ks, but we have a
				// // persistent connection, it will continually reboot).
	// REBOOT.
	// }
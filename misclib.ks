// Basic function library
CLEARSCREEN.

CORE:PART:GETMODULE("kOSProcessor"):DOEVENT("Open Terminal").
SET TERMINAL:WIDTH TO 50.
SET TERMINAL:HEIGHT TO 40.
SET CONFIG:IPU TO 500.

SET maxLinesToPrint TO 24. // Max # of lines in scrolling list
SET listLineStart TO 16. // First line for print scrolling list

LOCK MET TO MISSIONTIME.
print "T+ "+met.
FUNCTION NOTIFY {
  PARAMETER alertString.
  HUDTEXT("kOS: " + alertString, 5, 2, 50, WHITE, false).
}

//Scrolling print setup
SET printList TO LIST().
FUNCTION scrollPrint {
    PARAMETER nextPrint.
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
	scrollPrint("T+"+ROUND(MET,1)+" Downloading " + scrDwnName).
	IF EXISTS("1:/" + scrDwnName) {DELETEPATH("1:/" + scrDwnName).}
	ELSE {COPYPATH("0:/" + scrDwnName,"1:/").}
	scrollPrint("T+"+ROUND(MET,1)+ " " + scrDwnName + " succesfully downloaded").
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
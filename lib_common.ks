//common library for a	all scripts (general funtctions)

CORE:DOEVENT("Open Terminal").
CLEARSCREEN.
SET TERMINAL:WIDTH TO 50.	
SET TERMINAL:HEIGHT TO 40.
SET CONFIG:IPU TO 500.
LOCK MET TO ROUND(MISSIONTIME,0).
SET maxLinesToPrint TO 24. // Max # of lines in scrolling list
SET listLineStart TO 16. // First line for print scrolling list
SET printList TO LIST().

FUNCTION scrollPrint{
    PARAMETER nextPrint.
	PARAMETER tStamp IS TRUE.
	IF tStamp {SET nextPrint TO "T+ "+ MET + " " + nextPrint.}
    printList:ADD(nextPrint).
    UNTIL printList:LENGTH <= maxLinesToPrint {printList:REMOVE(0).}.
    LOCAL currentLine IS listLineStart.
    FOR printLine in printList {
        PRINT "                                                 " AT (0,currentLine).
        PRINT printLine AT (0,currentLine).
        SET currentLine TO currentLine+1.
}

FUNCTION prettyDisplay{
PRINT "  Current Mode =" AT (0,0).
PRINT "==================================================" AT (0,2).
PRINT "                |                |" AT (0,3).
PRINT "                |                |" AT (0,4).
PRINT "                |                |" AT (0,5).
PRINT "----------------+----------------+----------------" AT (0,6).
PRINT "                |                |" AT (0,7).
PRINT "                |                |" AT (0,8).
PRINT "                |                |" AT (0,9).
PRINT "----------------+----------------+----------------" AT (0,10).
PRINT "                |                |" AT (0,11).
PRINT "                |                |" AT (0,12).
PRINT "                |                |" AT (0,13).
PRINT "==================================================" AT (0,14).
}

FUNCTION hudPrint {
  PARAMETER alertString.
  PARAMETER alertColor IS WHITE
  HUDTEXT("kOS: " + alertString, 5, 2, 50, alertColor, false).
  }

FUNCTION scrReq{
	PARAMETER reqName.
	IF EXISTS ("1:/"+ reqName) {
	RUNONCEPATHPATH(reqName).
	}
	ELSE {
		scrLoad(reqName).
		RUNONCEPATH(reqName).
	}
}

FUNCTION scrHas{
	PARAMETER hasName.
	PARAMETER hasVol
	IF EXISTS (hasVol + ":/" + hasName) {RETURN TRUE.}
	ELSE {RETURN FALSE.}	
}

FUNCTION scrLoad{
	PARAMETER loadName.
	scrollPrint(" Downloading " + loadName,TRUE).
	IF EXISTS("1:/" + loadName) {DELETEPATH("1:/" + loadName).}
	{COPYPATH("0:/" + scrLoadName,"1:/").}
	scrollPrint(loadName + " succesfully downloaded").
}

FUNCTION scrDelete{
	PARAMETER scrDelName.
	IF EXISTS("1:/" + scrDelName) {
		DELETEPATH("1:/" + scrDelName).
		scrollPrint(scrDelName + " succesfully deleted",TRUE).	
	}
	ELSE {scrollPrint("File not found",TRUE)}

}

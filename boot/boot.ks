// Basic boot scrip
LOCK MET TO MISSIONTIME.

IF SHIP:CONNECTION:ISCONNECTED OR SHIP:STATUS = "PRELAUNCH" {COPYPATH("0:/misclib.ks","1:/").}
RUNPATH("1:/misclib.ks").
// THE ACTUAL BOOTUP PROCESS
IF SHIP:STATUS = "PRELAUNCH" {SET updateScript TO SHIP:NAME+".prelaunch.ks".}
ELSE {SET updateScript TO SHIP:NAME + SHIP:NAME+".update.ks".}
PRINT updateScript.
// If we have a connection, see if there are new instructions. If so, download
// and run them.
IF SHIP:CONNECTION:ISCONNECTED OR SHIP:STATUS = "PRELAUNCH"{
	scrollPrint("T+"+ROUND(MET,1)+" Checking for updated instructions").
	IF HAS_FILE(updateScript, 0) {
	scrollPrint("T+"+ROUND(MET,1)+" New instructions located - downloading").
	DOWNLOAD(updateScript).
	WAIT 1.
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
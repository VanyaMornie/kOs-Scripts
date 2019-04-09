// Basic boot script (new) v 0.1.0

IF SHIP:CONNECTION:ISCONNECTED OR SHIP:STATUS = "PRELAUNCH" {COPYPATH("0:/lib_common.ks","1:/").}
RUNONCEPATH("1:/lib_common.ks").

// THE ACTUAL BOOTUP PROCESS
IF SHIP:STATUS = "PRELAUNCH" {SET updateScript TO SHIP:NAME+".prelaunch.ks".}
ELSE {SET updateScript TO SHIP:NAME+".update.ks".}

scrollPrint(updateScript,FALSE).

// If we have a connection, see if there are new instructions. If so, download
// and run them.
IF SHIP:CONNECTION:ISCONNECTED OR SHIP:STATUS = "PRELAUNCH"{
	scrollPrint("Checking for updated instructions").
	IF HAS_FILE(updateScript, 0) {
		scrollPrint("New instructions located - downloading").
		DOWNLOAD(updateScript).
		WAIT 1.
		RUNONCEPATH(updateScript).
	}
	ELSE {
		scrollPrint("No new instructions found").
	}
	
}
  // If a startup.ks file exists on the disk, run that.
IF HAS_FILE("startup.ks", 1) {
	RUNONCEPATH(startup).
	}
	// ELSE {
	// WAIT UNTIL SHIP:CONNECTION:ISCONNECTED.
	// WAIT 10.	// Avoid thrashing the CPU (when no startup.ks, but we have a
				// // persistent connection, it will continually reboot).
	// REBOOT.
	// }
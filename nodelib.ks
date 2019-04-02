//maneuver node script
//written by /u/elvander
//Version track
SET scrVer TO 0.1. 
// PARAMETER manPoint.
// LOCK MET TO MISSIONTIME.

FUNCTION MNV_LEAD { //get lead time for node burns
	// Get initial acceleration.
	SET a0 TO maxthrust / mass.
	SET nDV TO NEXTNODE:BURNVECTOR:MAG.
	// In the pursuit of a1...
	// What's our effective ISP?
	SET eIsp TO 0.
	LIST engines IN my_engines.
	FOR eng IN my_engines {SET eIsp TO eIsp + eng:maxthrust / maxthrust * eng:isp.}
	// What's our effective exhaust velocity?
	SET Ve TO eIsp * g0.
	// What's our final mass?
	SET final_mass TO mass*CONSTANT:e^(-1*nDV/Ve).
	// Get our final acceleration.
	SET a1 TO maxthrust / final_mass.
	// All of that ^ just to get a1..
	// Get the time it takes to complete the burn.
	SET brnTime TO nDV/((a0 + a1)/2).

	RETURN brnTime.
}

FUNCTION MNV_APONODE {
	PARAMETER tarAlt.
	PARAMETER nETA.
// create apoapsis maneuver node
	scrollPrint("T+"+ROUND(MET(),1)+" Apoapsis maneuver, orbiting " + BODY:NAME).
	scrollPrint("T+"+ROUND(MET(),1)+" Apoapsis: " + ROUND(APOAPSIS/1000) + "km").
	scrollPrint("T+"+ROUND(MET(),1)+" Periapsis: " + ROUND(PERIAPSIS/1000) + "km -> " + ROUND(tarAlt/1000) + "km").
// present orbit properties
	SET curApoRad TO rb + APOAPSIS.	// current radius of apoapsis
	SET curSMA TO SHIP:ORBIT:SEMIMAJORAXIS.	//current Semi-Major Axis
	SET curVel TO SQRT(mu*((2/curApoRad)-(1/curSMA))). // Velocity at current apoapsis
// future orbit properties
	set tarSMA TO (curApoRad + tarAlt + rb)/2. // semi major axis target orbit
	set tarVel TO SQRT(mu*(2/curApoRad-(1/tarSMA))).
// setup node 
	SET brnDV TO tarVel - curVel.
	scrollPrint("T+"+ROUND(MET(),1)+" Apoapsis burn: " + ROUND(curVel) + ", dv:" + ROUND(brnDV) + " -> " + ROUND(tarVel) + "m/s").
	SET nd to NODE(TIME:SECONDS + nEta, 0, 0, brnDV).
	ADD nd.
	scrollPrint("T+"+ROUND(MET(),1)+" Node created.").
	SET burnNode TO NEXTNODE.

	PRINT "Steer to burn node       " AT (17,0).
	
	RETURN brnDV.
	
}

FUNCTION MNV_NODE {
	PARAMETER tarAlt.
	PARAMETER nETA.
// create apoapsis maneuver node
	scrollPrint("T+"+ROUND(MET(),1)+" New maneuver, orbiting " + BODY:NAME).
	scrollPrint("T+"+ROUND(MET(),1)+" Apoapsis: " + ROUND(APOAPSIS/1000) + "km").
	scrollPrint("T+"+ROUND(MET(),1)+" Periapsis: " + ROUND(PERIAPSIS/1000) + "km -> " + ROUND(tarAlt/1000) + "km").
// present orbit properties
	SET curApoRad TO rb + APOAPSIS.	// current radius of apoapsis
	SET curSMA TO SHIP:ORBIT:SEMIMAJORAXIS.	//current Semi-Major Axis
	SET curVel TO SQRT(mu*((2/curApoRad)-(1/curSMA))). // Velocity at current apoapsis
// future orbit properties
	set tarSMA TO (curApoRad + tarAlt + rb)/2. // semi major axis target orbit
	set tarVel TO SQRT(mu*(2/curApoRad-(1/tarSMA))).
// setup node 
	SET brnDV TO tarVel - curVel.
	scrollPrint("T+"+ROUND(MET(),1)+" Engine burn: " + ROUND(curVel) + ", dv:" + ROUND(brnDV) + " -> " + ROUND(tarVel) + "m/s").
	SET nd to NODE(TIME:SECONDS + nEta, 0, 0, brnDV).
	ADD nd.
	scrollPrint("T+"+ROUND(MET(),1)+" Node created.").
	SET burnNode TO NEXTNODE.

	PRINT "Steer to burn node       " AT (17,0).
	
	RETURN brnDV.
}


FUNCTION MNV_WARPNODE {
	PARAMETER mnvRunMode IS 0.
	PARAMETER useWarp IS TRUE.
	SET burnNode TO NEXTNODE.
	MNV_LEAD().
	SET failedToSteer TO TRUE.
	SET leadTime TO 0.5 * brnTime.
	SET wrpCan TO (TIME:SECONDS + burnNode:ETA - leadTime - 10). // 10 second buffer
	// IF WARPMODE "PHYSICS".{SET WARP TO 0. SET WARPMODE TO "RAILS".}
	SET tset TO 0.
	// IF WARP > 0 AND failedToSteer {SET WARP TO 0.}. // enforce warp 0 in case user previously set physwarp so runmode 6 will be timewarp not physwarp
	SET WARPMODE TO "RAILS".
	SET steerTo TO burnNode.
	SET stErrX TO burnNode:BURNVECTOR:NORMALIZED:X - FACING:VECTOR:NORMALIZED:X.
	SET stErrY TO burnNode:BURNVECTOR:NORMALIZED:Y - FACING:VECTOR:NORMALIZED:Y.
	SET stErrZ TO burnNode:BURNVECTOR:NORMALIZED:Z - FACING:VECTOR:NORMALIZED:Z.
	SET stErr TO sqrt(stErrX^2+stErrY^2+stErrZ^2).
        IF useWarp {
            IF stErr < 0.01 {
                // SET mnvRunMode TO 6.
                //scrollPrint("T+"+ROUND(MET(),1)+" Warping to ignition time").
                SET failedToSteer TO False.
				//SET runMode TO 6.
            }
            ELSE IF burnNode:ETA <= leadTime {
                SET mnvRunMode TO 8.
                printList:ADD("T+"+ROUND(MET(),1)+" Failed to steer to node before burn start").
                scrollPrint("        Igniting engines and hoping for the best").
                SET failedToSteer TO True.
                SET tset TO 1.
            }.
        }
        ELSE IF NOT useWarp {
            IF burnNode:ETA <= leadTime {
                SET mnvRunMode TO 8.
                IF stErr < 0.1 {SET failedToSteer TO False.}.
                ELSE {SET failedToSteer TO True.}.
            }.
        }.
	// Warp to node
	IF failedToSteer = FALSE AND WARP = 0 AND TIME:SECONDS < wrpCan {WARPTO(wrpCan).} // 10 warp if steering aligned
	// Wait for warp
			//scrollPrint("T+"+ROUND(MET(),1)+" brnTime " + ROUND(brnTime,0) + ", ETA " + burnNode:ETA).
			SET tset TO 0.
			IF burnNode:ETA <= leadTime {
				SET tset TO 1.
				SET mnvRunMode TO 8.
				SET runMode TO mnvRunMode.
				RETURN runMode.
			}.
			IF brnTime >= burnNode:ETA { //<= brnTime{
			scrollPrint("T+"+ROUND(MET(),1)+" Engine ignition in " + ROUND(burnNode:ETA - leadTime,0) +"s").
			SET mnvRunMode TO 8.
			}
		ELSE SET steerTo TO burnNode.
	//}
	SET runMode TO mnvRunMode.
	RETURN runMode.
}

FUNCTION MNV_EXENODE {
	PARAMETER mnvRunMode.
	SET burnNode TO NEXTNODE.
	MNV_LEAD().
	SET leadTime TO 0.5 * brnTime.
	IF burnNode:ETA <= leadTime. {
		SET tset TO 1.
		//scrollPrint("T+"+ROUND(MET(),1)+" Engine ignition").	
	}
	LOCK burnTimeRemaining TO burnNode:DELTAV:MAG/MAX(AVAILABLETHRUST/SHIP:MASS,0.001).
	// Stage if staging required before burn end and would put debris in orbit ### TODO
	IF burnTimeRemaining > 2 {
		SET tset TO 1.
		SET steerTo TO burnNode.
	}
	ELSE {
		UNLOCK STEERING.
		SAS ON.
		scrollPrint("T+"+ROUND(MET(),1)+" Burn nearly complete, timing remainder").
		wait 0.001.
		SET finalBurnTime TO burnTimeRemaining - 0.1. // -0.1s time adjustment based on testing.
		SET burnEndTime TO TIME:SECONDS + finalBurnTime.
		WAIT UNTIL TIME:SECONDS > burnEndTime.
		SET tset TO 0.
		UNLOCK burnTimeRemaining.
		SET mnvRunMode TO 9.
		scrollPrint("T+"+ROUND(MET(),1)+" Burn complete").
		SET runMode TO mnvRunMode.
		RETURN runMode.
	}
}
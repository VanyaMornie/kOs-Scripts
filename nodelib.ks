//maneuver node script
//written by /u/elvander
//Version track
SET scrVer TO 0.1. 
// PARAMETER manPoint.

<<<<<<< HEAD
// FUNCTION circNode {
// SET manAp TO APOAPSIS + SHIP:BODY:RADIUS.
// SET sMajAx TO SHIP:ORBIT:SEMIMAJORAXIS.
// SET tarMajAx TO 
// SET rPeriapsis TO PERIAPSIS + SHIP:BODY:RADIUS.
// SET rApoapsis TO APOAPSIS + SHIP:BODY:RADIUS.
// SET bETA TO TIME:SECONDS+ETA:APOAPSIS.
// SET nodeDeltaV TO SQRT(SHIP:BODY:MU/(rApoapsis))*(1-SQRT(2*rPeriapsis/(rPeriapsis+rApoapsis))).
// SET burnNode TO NODE(bETA, 0, 0, nodeDeltaV).
// printList:ADD("T+"+ROUND(MET,1)+" Circ. burn = "+ROUND(nodeDeltaV,1)+" m/s in "+ROUND(ETA:APOAPSIS)+" s").
// }


FUNCTION MNV_APONODE {

PARAMETER tarAlt

// create apoapsis maneuver node
	scrollPrint("T+"+ROUND(MET,1)+" Apoapsis maneuver, orbiting " + body:name).
	scrollPrint("T+"+ROUND(MET,1)+" Apoapsis: " + round(apoapsis/1000) + "km").
	scrollPrint("T+"+ROUND(MET,1)+" Periapsis: " + round(periapsis/1000) + "km -> " + round(alt/1000) + "km").
// present orbit properties
	SET curApoRad TO rb + APOAPSIS.	// current radius of apoapsis
	SET curSMA TO SHIP:ORBIT:SEMIMAJORAXIS.	//current Semi-Major Axis
	SET curVelApo TO SQRT(mu*((2/curApoRad)-(1/curSMA))). // Velocity at current apoapsis
// future orbit properties
	set tarSMA TO tarAlt + rb. // semi major axis target orbit
	set tarVelApo TO SQRT(mu*(2/curApoRad-(1/tarSMA))).
// setup node 
	SET brnDV TO tarVelApo - curVelApo.
	scrollPrint("T+"+ROUND(MET,1)+" Apoapsis burn: " + round(va) + ", dv:" + round(brnDV) + " -> " + round(v2) + "m/s").
	set nd to node(time:seconds + eta:apoapsis, 0, 0, brnDV).
	add nd.
	
	RETURN brnDV.
	scrollPrint("T+"+ROUND(MET,1)+" Node created.").
}
=======
PARAMETER manPoint.

FUNCTION circNode {
SET manAp TO APOAPSIS + SHIP:BODY:RADIUS.
SET sMajAx TO SHIP:ORBIT:SEMIMAJORAXIS.
SET tarMajAx TO 
SET rPeriapsis TO PERIAPSIS + SHIP:BODY:RADIUS.
SET rApoapsis TO APOAPSIS + SHIP:BODY:RADIUS.
SET bETA TO TIME:SECONDS+ETA:APOAPSIS.
SET nodeDeltaV TO SQRT(SHIP:BODY:MU/(rApoapsis))*(1-SQRT(2*rPeriapsis/(rPeriapsis+rApoapsis))).
SET burnNode TO NODE(bETA, 0, 0, nodeDeltaV).
printList:ADD("T+"+ROUND(MET,1)+" Circ. burn = "+ROUND(nodeDeltaV,1)+" m/s in "+ROUND(ETA:APOAPSIS)+" s").
}

FUNCTION MNV_APONODE {
	PARAMETER tarAlt.
// create apoapsis maneuver node
	scrollPrint("T+"+ROUND(MET,1)+" Apoapsis maneuver, orbiting " + body:name.
	scrollPrint("T+"+ROUND(MET,1)+" Apoapsis: " + round(apoapsis/1000) + "km".
	scrollPrint("T+"+ROUND(MET,1)+" Periapsis: " + round(periapsis/1000) + "km -> " + round(alt/1000) + "km".
// present orbit properties
	SET curApoRad TO rb + APOAPSIS.	// current radius of apoapsis
	SET curSMA TO SHIP:ORBIT:SEMIMAJORAXIS.	//current Semi-Major Axis
	SET curVelApo TO SQRT(mu*((2/curApoRad)-(1/curSMA)). // Velocity at current apoapsis
// future orbit properties
	set tarSMA TO tarAlt + rb. // semi major axis target orbit
	set tarVelApo TO SQRT(mu*(2/curApoRad-(1/tarSMA)).
// setup node 
	SET brnDV TO tarVelApo - curVelApo.
	scrollPrint("T+"+ROUND(MET,1)+" Apoapsis burn: " + round(va) + ", dv:" + round(deltav) + " -> " + round(v2) + "m/s".
	set nd to node(time:seconds + eta:apoapsis, 0, 0, deltav).
	add nd.
	}
	RETURN brnDV.
	scrollPrint("T+"+ROUND(MET,1)+" Node created.".
}
>>>>>>> launch-dev

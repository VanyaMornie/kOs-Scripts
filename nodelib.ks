//maneuver node script
//written by /u/elvander
SET scrVer TO 0.1. //Version track

FUNCTION circNode {
SET rPeriapsis TO PERIAPSIS + SHIP:BODY:RADIUS.
SET rApoapsis TO APOAPSIS + SHIP:BODY:RADIUS.
SET bETA TO TIME:SECONDS+ETA:APOAPSIS.
SET nodeDeltaV TO SQRT(SHIP:BODY:MU/(rApoapsis))*(1-SQRT(2*rPeriapsis/(rPeriapsis+rApoapsis))).
SET burnNode TO NODE(bETA, 0, 0, nodeDeltaV).
printList:ADD("T+"+ROUND(MET,1)+" Circ. burn = "+ROUND(nodeDeltaV,1)+" m/s in "+ROUND(ETA:APOAPSIS)+" s").


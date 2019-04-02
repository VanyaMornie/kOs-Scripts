// set celestial body properties
// ease future parametrisation
SET b TO BODY:NAME.
SET mu TO BODY:MU.
SET rb TO BODY:RADIUS.
SET bRot TO BODY:ROTATIONPERIOD.
SET soi TO BODY:SOIRADIUS.
SET atmTop TO BODY:ATM:HEIGHT.
SET pi TO CONSTANT:PI.
SET e TO CONSTANT:E.
SET g0 TO CONSTANT:g0.
 
IF b = "Kerbin" {
    SET lowOrb TO 80000.	// low orbit altitude [m]
	SET hiOrb TO 250000.	// high orbit altitude (m)		
}
if b = "Mun" {
    SET safeOrb TO 14000.
	//SET hiOrb TO
}
if b = "Minmus" {
    set lorb to 10000.
}
if mu = 0 {
    print "T+" + round(missiontime) + " WARNING: no body properties for " + b + "!".
}
if mu > 0 {
    print "T+" + round(missiontime) + " Loaded body properties for " + b.
}
// fix NaN and Infinity push on stack errors, https://github.com/KSP-KOS/KOS/issues/152
set config:safe to False.
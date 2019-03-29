// set celestial body properties
// ease future parametrisation
SET b TO BODY:NAME.
SET mu TO BODY:MU.
SET rb TO BODY:RADIUS.
SET soi TO BODY:SOIRADIUS.
SET limAtm TO BODY:ATM:HEIGHT.
 


IF b = "Kerbin" {
    SET lowOrb TO 70000.	// low orbit altitude [m]
	SET hiOrb TO 250000.	// high orbit altitude (m)		
}
if b = "Mun" {
    set mu to 6.5138398*10^10.
    set rb to 200000.
    set soi to 2429559.
    set ad0 to 0.
    set lorb to 14000. 
}
if b = "Minmus" {
    set mu to 1.7658000*10^9.
    set rb to 60000.
    set soi to 2247428.
    set ad0 to 0.
    set lorb to 10000.
}
if mu = 0 {
    print "T+" + round(missiontime) + " WARNING: no body properties for " + b + "!".
}
if mu > 0 {
    print "T+" + round(missiontime) + " Loaded body properties for " + b.
}
set euler to 2.718281828.
set pi to 3.1415926535.
// fix NaN and Infinity push on stack errors, https://github.com/KSP-KOS/KOS/issues/152
set config:safe to False.
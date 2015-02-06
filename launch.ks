//test launch script - runmodes and basic theory credit to KK4TEE - https://gist.github.com/KK4TEE/c41b4fb789a01cef6122

//Variables

declare parameter TgtApa


//intial state
SAS off.
RCS off.
lights off.
lock throttle to 0.
gear off.
brakes off.

set runmode to 2.

if ALT:RADAR < 50
	set runmode to 1.

clearscrean.

//terminal print data
print "Program stage: " launchstage.
print "Target Orbit:  " (TgtApa/1000) "km" at (0,10).
print "Current Alt:   " round(SHIP:ALTITUDE) "m" at (0,11).
print "Apoapsis:      " round(SHIP:APOAPSIS) "m" as (0,12).
if SHIP:PERIAPSIS < 0
	print "Periapsis:    " round(SHIP:PERIAPSIS) "m" at (0,13).
else
	print "Periapsis:    "Sub-orbital!m" at (0,13).

//flameout check

SET numOut to 0.
LIST ENGINES IN engines. 
FOR eng IN engines 

    IF eng:FLAMEOUT 
    	
        SET numOut TO numOut + 1.
    	

if numOut > 0
	stage.

//launch program

until runmode = 0

	if runmode = 1
		{
		lock steering to UP.
		set Tval to 1.
		wait 2.
		stage.
		set runmode to 2.
		}
	
	if runmode = 2
		{
		if ALT:RADAR < 1500
			lock steering to heading (90,90).
		else
		
			lock steering to heading (90,88).
		}

	if SHIP:ALTITUDE > 7000
		set runmode to 3.

	if runmode = 3
		set Pprog to max(5,90
	





//Launch Script
//Written by /u/Elvander, much credit to /u/only_to_downvote

//Usage
//run launch(<desired apogee>,				//km (required)
//			(<inclination>,					//default 0
//			(<turn start>,					//default 500m AGL
//			(<turn end>,					//default 50km (atmosphere only)
//			(<turn exponent>,				//shape the ascent curve
//LAUNCH TO ORBIT

 //node library
PARAMETER tarAlt.
PARAMETER tarInc IS 0.
PARAMETER trnStart IS 500.
PARAMETER trnEnd IS 35000.
PARAMETER turnExponent IS 0.7.

REQUIRE("bodylib.ks").
REQUIRE("nodelib.ks").
REQUIRE("misclib.ks").
//Variables
SET tSet TO 0.
SET tarAlt TO tarAlt*1000.
SET orbitError TO 5.
SET maxq TO 7000.

// Staging delays (time after detection of engine shutdown before staging or between staging actions)
SET boosterStageDelay TO 2.
SET stageDelay TO 3. // Should be greater than 1 to prevent problems.

//steering tweaks
SET STEERINGMANAGER:ROLLPID:KP TO 0. // Only enforce roll rate, not specific roll angle
SET STEERINGMANAGER:ROLLPID:KI TO 0.
 
// Miscellaneous
SET allowAbort TO True. // whether or not to allow code to automatically trigger abort
SET useWarp TO True. // whether or not to use timewarp to Apoapsis burn. Not recommended if using persistent rotation mod.
SET logTimeIncrement TO 30. // base increment in seconds between periodic log entries; doubles while coasting, quadruples while timewarping)
SET logVerboseData TO FALSE. // turn verbose data log on or off
SET verboseLogIncrement TO 1.0. // time increment for verbose log // percent error allowed in orbital apoapsis or periapsis  
SET maxNumReboost TO 3. // maximum number of times re-boost burn is allowed before aborting if apoapsis if falling
SET limitToTermV TO False. // works for any atmosphere model, terminal V based on ship's forces, but generally not all that useful. Need very high TWR to break terminal velocity.
SET autoAscent TO TRUE.

//Error Checks

//Is orbit clear of atmosphere or highest peak
IF tarAlt*(1-orbitError/100)<atmTop {
    PRINT "Target orbit apopapsis of "+tarAlt*(1-orbitError/100)+"m  based on".
    PRINT "orbit error threshold is below atmosphere height".
    PRINT "of "+atmTop+"m".
    PRINT " ".
    PRINT "Use ctrl+c to cancel program and try again".
    PRINT " ".
    WAIT UNTIL False.
}

// Make sure all launch clamps are on a single stage
SET launchClampStage TO 999.
FOR p in SHIP:PARTS {
    IF p:MODULES:CONTAINS("LaunchClamp") {
        IF launchClampStage = 999 SET launchClampStage TO p:STAGE.
        ELSE IF p:STAGE <> launchClampStage {
            PRINT "Not all launch clamps are in a single Stage".
			PRINT "You will not go to space today...".
            PRINT " ".
            PRINT "Use ctrl+c to cancel program and try again".
            PRINT " ".
            WAIT UNTIL False.          
        }
    }
}

//inclincation check
IF ABS(tarInc) < FLOOR(ABS(LATITUDE)) OR ABS(tarInc) > (180 - CEILING(ABS(LATITUDE))) {
    PRINT "Desired inclination impossible. ".
    PRINT "Magnitude must be larger than or equal to the ".
    PRINT "current latitude of "+ROUND(LATITUDE,1)+" deg".
    PRINT " ".
    PRINT "Use ctrl+c to cancel program and try again".
    PRINT " ".
    WAIT UNTIL False.
}
	

//intial state (courtesy /u/only_to_downvote
UNLOCK all.
SET SHIP:CONTROL:PILOTMAINTHROTTLE TO 0.

IF logVerboseData {
    LOG 1 TO launchDataLog.csv. DELETEPATH("launchDataLog.csv").
    // Verbose data log header
    LOG "M.E.T. [s], Sea Level Altitude [m], Radar Altitude [m], Latitude [deg], Longitude [deg], Surface Velocity [m/s], Orbital Velocity [m/s], Vertical Speed [m/s], Ground Speed [m/s], Apoapsis [m], Time to Apoapsis [s], Periapsis [m], Time to Periapsis [s], Inclination [deg], Mass [t], Max Thrust [kN], Current Thrust [kN], T.W.R., % Terminal Velocity, Trajectory Preferred Pitch [deg], Pitch Command [deg], Vessel Pitch [deg], Heading Command [deg], Vessel Heading [deg], dv Spent [m/s], Dynamic Pressure [kPa]" TO launchDataLog.csv.
}

// solid motor info for current stage (used for ullage staging operations)
FUNCTION stageSolidInfo {
    LOCAL solidMinBurnTime IS 99999.
    LOCAL solidTotalThrust IS 0.
    LOCAL engList IS LIST().
    LIST ENGINES IN engList.
    FOR e in engList {
        IF e:IGNITION AND e:RESOURCES:LENGTH <> 0 {
            FOR r in e:RESOURCES {
                IF r:NAME = "SolidFuel" {
                    LOCAL isp IS e:ISP. IF isp = 0 SET isp TO 0.001.
                    LOCAL thrust IS e:THRUST.
                    SET solidTotalThrust TO solidTotalThrust + thrust.
                    LOCAL mdot IS thrust/(isp*9.81). IF mdot = 0 SET mdot TO 0.001.
                    LOCAL burnTime IS (r:AMOUNT*0.0075)/mdot.
                    IF burnTime < solidMinBurnTime SET solidMinBurnTime TO burnTime.
                }
            }
        }
    }
    RETURN LIST(solidMinBurnTime, solidTotalThrust).
}
	
FUNCTION activeEngineInfo {
    // ## should technically be updated to account for engines not pointing directly aft
    LIST ENGINES IN engList.
    LOCAL currentT IS 0.
    LOCAL maxT IS 0.
    LOCAL mDot IS 0.
    FOR eng IN engList {
        IF eng:IGNITION {
            SET maxT TO maxT + eng:AVAILABLETHRUST.
            SET currentT TO currentT + eng:THRUST.
            IF NOT eng:ISP = 0 SET mDot TO mDot + currentT / eng:ISP.
        }
    }
    IF mDot = 0 LOCAL avgIsp IS 0.
    ELSE LOCAL avgIsp IS currentT / mDot.
    RETURN LIST(currentT, maxT, avgIsp, mDot).
}	

// Stage dV calc
FUNCTION deltaVstage {
    FOR p in SHIP:PARTS {
        IF p:MODULES:CONTAINS("CModuleFuelLine") {
            RETURN -1. // Unable to calculate deltaV if fuel lines complicate fuel flow pattern.
        }
    }
	LOCAL fuelMass IS STAGE:LIQUIDFUEL*0.005 + STAGE:OXIDIZER*0.005 + STAGE:SOLIDFUEL*0.0075.
	   
    // thrust weighted average isp
    LOCAL thrustTotal IS 0.
    LOCAL mDotTotal IS 0.
    LOCAL engList IS LIST(). LIST ENGINES IN engList.
    FOR eng in engList {
        IF eng:IGNITION {
            LOCAL t IS eng:AVAILABLETHRUST.
            SET thrustTotal TO thrustTotal + t.
            IF eng:ISP <> 0 SET mDotTotal TO  mDotTotal + (t / eng:ISP).
        }
    }
    IF mDotTotal <> 0 LOCAL avgIsp IS thrustTotal/mDotTotal.
    ELSE LOCAL avgIsp IS 0.
       
    // deltaV calculation as Isp*g*ln(m0/m1).
    LOCAL deltaV IS avgIsp*9.81*ln(SHIP:MASS / (SHIP:MASS-fuelMass)).
   
    RETURN deltaV.
}

// required kOS lib functions included here for keeping program in a single file
function compass_for {
  parameter ves.
 
  local pointing is ves:facing:forevector.
  local east is vcrs(ves:up:vector, ves:north:vector).
 
  local trig_x is vdot(ves:north:vector, pointing).
  local trig_y is vdot(east, pointing).
 
  local result is arctan2(trig_y, trig_x).
 
  if result < 0 {
    return 360 + result.
  }
  else {
    return result.
  }
}
function pitch_for {
  parameter ves.
 
  return 90 - vang(ves:up:vector, ves:facing:forevector).
}

//Loop Start
SET WARPMODE TO "PHYSICS".
SET tset TO 0.
LOCK THROTTLE to tset. // required for odd kOS bug with locking throttle multiple times in a script
SET steerTo TO UP.
SET launchTime TO TIME:SECONDS+6.
SET logTime TO launchTime+logTimeIncrement.
SET verboseLogTime TO launchTime.
LOCK MET TO MISSIONTIME.
LOCK cDown TO TIME:SECONDS-launchTime.
SET launchLoc TO SHIP:GEOPOSITION.
SET launchAlt TO ALTITUDE.
SET currentStageNum TO 1.
SET stagingInProgress TO False.
SET launchComplete TO False.
SET runMode TO -1.
SET numParts TO SHIP:PARTS:LENGTH.
SET boostBurn TO FALSE.
SET trajectoryPitch TO 90.
SET steerPitch TO 90.
SET triggerStage TO False.
SET numReboost TO 0.
SET throttleSetting TO 1.
SET boostStageTime TO TIME:SECONDS+100000.
SET stageTime TO TIME:SECONDS+100000.
SET ullageTime TO TIME:SECONDS+100000.
SET ullageDetect TO False.
SET ullageStageNeeded TO False.
SET ullageThrust TO 0.
SET ullageShutdown TO False.
SET engIgnoreList TO LIST().
SET flameoutDetect TO False.
SET dropTanksEmpty TO False.
SET tMin5 TO TRUE. SET tMin4 TO TRUE. SET tMin3 TO TRUE.
SET tMin2 TO TRUE. SET tMin1 TO TRUE. SET tMin0 TO TRUE.
SET tMinHold TO False.
SET timeStamp TO TIME:SECONDS.
SET accelVector TO V(0,0,0).
SET aeroForceLIST TO LIST(0,0,0).
SET broke30s TO False.
SET firstStageAllSolid TO True.
SET pctTerminalVel TO "N/A".
SET lastDVTime TO TIME:SECONDS.
SET dVSpent TO 0.
SET finalBurnTime TO 0.
SET runOnce TO True. SET runOnce2 TO True.
SET liquidFuelResources TO LIST("LiquidFuel","Oxidizer").

PRINT " Current Mode =" AT (1,0).
PRINT "==================================================" AT (0,2).
PRINT "Sea Lvl.        | Ground         | Orbit" AT (0,3).
PRINT "  Alt.          |  Dist.         | Incl." AT (0,4).
PRINT "  [km]          |  [km]          | [deg]" AT (0,5).
PRINT "----------------+----------------+----------------" AT (0,6).
PRINT "Apoap.          |Periap.         |  TWR" AT (0,7).
PRINT " [km]           | [km]           |Max TWR" AT (0,8).
PRINT " (ETA)          | (ETA)          |Runmode" AT (0,9).
PRINT "----------------+----------------+----------------" AT (0,10).
PRINT " Total          | Stage          | Spent" AT (0,11).
PRINT "Vac. dV         |  dV            |  dV" AT (0,12).
PRINT " [m/s]          | [m/s]          | [m/s]" AT (0,13).
PRINT "==================================================" AT (0,14).

IF SHIP:BODY:ATM:EXISTS {
    WHEN ALTITUDE > atmTop*0.95 THEN {
        TOGGLE AG8.
        SET numParts TO SHIP:PARTS:LENGTH.
        printList:ADD("T+"+ROUND(MET(),1)+" Fairing/LES separation").
        LOG ("T+"+ROUND(MET(),1)+" Fairing separation") TO launchLog.txt.
    }
}

// Calculate launch azimuth
SET inertialAzimuth TO ARCSIN(MAX(MIN(COS(tarInc) / COS(launchLoc:LAT),1),-1)).
SET targetOrbitSpeed TO SQRT(SHIP:BODY:MU / (tarAlt+SHIP:BODY:RADIUS)).
SET rotVelX TO targetOrbitSpeed*SIN(inertialAzimuth) - (2*pi*rb/bRot).
SET rotVelY TO targetOrbitSpeed*COS(inertialAzimuth).
SET launchAzimuth TO ARCTAN(rotVelX / rotVelY).
IF tarInc < 0 {SET launchAzimuth TO 180-launchAzimuth.}.
SET steerHeading TO launchAzimuth.

//Launch loop start
UNTIL launchComplete {
//Pretty Countdown
    IF runMode = -1 {
        PRINT "Countdown" AT (17,0).
       
        IF cDown >= -5 AND tMin5 {
            PRINT "55555" AT (43,35).
            PRINT "5    " AT (43,36).
            PRINT "5555 " AT (43,37).
            PRINT "   55" AT (43,38).
            PRINT "5555 " AT (43,39).
            SAS ON.
            scrollPrint("T-5.0 Launch stability assist system activated").
            SET tMin5 TO FALSE.
        }
       
        IF cDOWN >= -4 AND tMin4 {
            PRINT "4   4 " AT (43,35).
            PRINT "4   4 " AT (43,36).
            PRINT "444444" AT (43,37).
            PRINT "    4 " AT (43,38).
            PRINT "    4 " AT (43,39).
            SET tMin4 TO FALSE.
        }
       
        IF NOT firstStageAllSolid {
            IF engInfo[0] < 0.95*engInfo[1] { // require current thrust > 95% max thrust to launch
                SET tMinHold TO True.
            }
            ELSE {
                IF runOnce2 {
                    scrollPrint("T"+ROUND(MET(),1)+" Main engine at full thrust").
                    SET runOnce2 TO False.
                }
                SET tMinHold TO False.
            }
        }
       
        IF cDown >= -3 AND tMin3 {
            PRINT "33333 " AT (43,35).
            PRINT "    33" AT (43,36).
            PRINT "  333 " AT (43,37).
            PRINT "    33" AT (43,38).
            PRINT "33333 " AT (43,39).
            LOCAL stageNumber IS STAGE:NUMBER.
            FOR p in SHIP:PARTS {
                IF p:STAGE >= launchClampStage-1 {
                    FOR resource IN p:RESOURCES {
                        IF liquidFuelResources:CONTAINS(resource:NAME) {
                            SET firstStageAllSolid TO False.
                        }
                    }
                }
            }
            IF firstStageAllSolid {
                SET tMin3 TO FALSE.
            }
            ELSE {
                STAGE.
                SET numParts TO SHIP:PARTS:LENGTH.
                SET ignitionTime to TIME:SECONDS.
                scrollPrint("T-3.0 Main engine ignition sequence begin").
                LOCK tset TO (TIME:SECONDS-ignitionTime)/2.
                SET tMin3 TO FALSE.
            }
        }
       
        IF cDown >= -2 AND tMin2 {
            PRINT " 2222 " AT (43,35).
            PRINT "2   22" AT (43,36).
            PRINT "  22  " AT (43,37).
            PRINT "22    " AT (43,38).
            PRINT "222222" AT (43,39).
            SET tMin2 TO FALSE.
        }
       
        IF cDown >= -1 AND tMin1 {
            PRINT "  11  " AT (43,35).
            PRINT " 1 1  " AT (43,36).
            PRINT "   1  " AT (43,37).
            PRINT "   1  " AT (43,38).
            PRINT " 11111" AT (43,39).  
            SET tMin1 TO FALSE.
        }
       
        IF cDown >= -0.1 AND tMinHold {
            PRINT " HOLD " AT (43,35).
            PRINT " HOLD " AT (43,36).
            PRINT " HOLD " AT (43,37).
            PRINT " HOLD " AT (43,38).
            PRINT " HOLD " AT (43,39).
            IF runOnce {
                SET runOnce TO False.
                scrollPrint("T-X.X HOLD - Waiting for engines to spool up").
            }
            SET launchTime TO TIME:SECONDS+0.1.
            SET tset to 1.
        }
       
        IF cDown >= 0 AND tMin0 {
            SET tSet to 1.
            STAGE.
            SET numParts TO SHIP:PARTS:LENGTH.
            IF STAGE:SOLIDFUEL > 0 {
                scrollPrint("T-0.0 SRB Ignition").
            }
            scrollPrint("T+0.0 Liftoff!").
            SET runMode to 0.
            SET tMin0 TO FALSE.
        }
       // One-time actions before initiating vertical ascent
        IF runMode = 0 {
            WAIT 0.
            SET launchTime TO TIME:SECONDS.
            // LOCK MET TO TIME:SECONDS-launchTime.
            SET logTime TO launchTime+logTimeIncrement.
            SET engInfo TO activeEngineInfo().
            SET launchTWR TO engInfo[1]/(SHIP:MASS*mu/(ALTITUDE+rb)^2).
            PRINT "      " AT (43,35).
            PRINT "      " AT (43,36).
            PRINT "      " AT (43,37).
            PRINT "      " AT (43,38).
            PRINT "      " AT (43,39).
            SET speedErrT0 TO 0.
            SET timeStamp TO TIME:SECONDS.     
            IF autoAscent { // Auto adjust pitch based on TWR
                SET trnEnd TO 0.128*atmTop*launchTWR + 0.5*atmTop. // Based on testing
                SET turnExponent TO MAX(1/(2.5*launchTWR - 1.7), 0.25). // Based on testing
                printList:ADD("T+"+ROUND(MET(),1)+" Using auto ascent trajectory with paramaters:").
                printList:ADD("        Turn End Alt. = "+ROUND(trnEnd)).
                scrollPrint("        Turn Exponent = "+ROUND(turnExponent,3)).
            } 
        }
    }   
// Initial vertical ascent to clear support structures
    IF runMode = 0 {
        PRINT "Initial vertical ascent" AT (17,0).
        IF WARP > 1 SET WARP TO 1. // limit physwarp to 2x for code stability
        IF ALT:RADAR > trnStart AND SHIP:AIRSPEED > 75 {
            SET runMode TO 1.
            scrollPrint("T+"+ROUND(MET(),1)+" Launch site cleared").
			scrollPrint("T+"+ROUND(MET(),1)+" Starting ascent guidance").
            SAS OFF.
            LOCK STEERING TO steerTo.
        }
    }
	// Ascent trajectory program until reach desired apoapsis  
    IF runMode = 1 {
        PRINT "Ascent Guidamce        " AT (17,0).
        IF WARP > 1 SET WARP TO 1. // limit physwarp to 2x for code stability
       
        IF stagingInProgress {
            SET ascentSteer TO SHIP:SRFPROGRADE. //Steer to surface prograde while staging
        }  
        ELSE {
            // Ship pitch control
            SET trajectoryPitch TO max(90-(((ALTITUDE-trnStart)/(trnEnd-trnStart))^turnExponent*90),0).
            SET steerPitch TO trajectoryPitch.
           
            //Keep time to apoapsis > 30s during ascent once it is above 30s
            IF broke30s AND ETA:APOAPSIS < 30 SET steerPitch TO steerPitch+(30-ETA:APOAPSIS).
            ELSE IF ETA:APOAPSIS > 30 AND NOT broke30s SET broke30s TO True.
           
            // Ship compass heading control
            IF ABS(SHIP:OBT:INCLINATION - ABS(tarInc)) > 2 {
                SET steerHeading TO launchAzimuth.
            }
            ELSE { // Feedback loop once close to desired inclination
                IF tarInc >= 0 {
                    IF VANG(VXCL(SHIP:UP:VECTOR, SHIP:FACING:VECTOR), SHIP:NORTH:VECTOR) <= 90 {
                        SET steerHeading TO (90-tarInc) - 2*(ABS(tarInc) - SHIP:OBT:INCLINATION).
                    }
                    ELSE {
                        SET steerHeading TO (90-tarInc) + 2*(ABS(tarInc) - SHIP:OBT:INCLINATION).
                    }
                }
                ELSE IF tarInc < 0 {
                    SET steerHeading TO (90-tarInc) + 2*(ABS(tarInc) - SHIP:OBT:INCLINATION).
                }
            }
			
			SET ascentSteer TO HEADING(steerHeading, steerPitch).
						
			// Don't pitch too far off surface prograde while under high dynamic pressrue
            IF SHIP:Q > 0 SET angleLimit TO MAX(3, MIN(90, 5*LN(0.9/SHIP:Q))).
            ELSE SET angleLimit TO 90.
            SET angleToPrograde TO VANG(SHIP:SRFPROGRADE:VECTOR,ascentSteer:VECTOR).
            IF angleToPrograde > angleLimit {
                SET ascentSteerLimited TO (angleLimit/angleToPrograde * (ascentSteer:VECTOR:NORMALIZED - SHIP:SRFPROGRADE:VECTOR:NORMALIZED)) + SHIP:SRFPROGRADE:VECTOR:NORMALIZED.
                SET ascentSteer TO ascentSteerLimited:DIRECTION.
            }
        }
        SET steerTo TO ascentSteer.
		
		IF NOT stagingInProgress {
            SET tset TO 1.
            SET pctTerminalVel TO "N/A".
        }     
       
        // Ascent mode end conditions
        IF APOAPSIS >= tarAlt {
            SET tset TO 0.
            SET trajectoryPitch TO 0.
            SET steerPitch TO 0.
            scrollPrint("T+"+ROUND(MET(),1)+" Desired apoapsis reached").
            SET pctTerminalVel TO "N/A".
            IF ALTITUDE < atmTop {
                SET runMode TO 2.
                scrollPrint("T+"+ROUND(MET(),1)+" Steering prograde until out of atmosphere").
            }
            ELSE {
                SET runMode TO 3.
            }
        }
    }
// Coast out of atmosphere 
    IF runMode = 2 {
        PRINT "Coast out of atmosphere  " AT (17,0).
        IF WARP > 1 SET WARP TO 1. // limit physwarp to 2x for code stability
        SET steerTo TO SHIP:SRFPROGRADE.
        //cheaty atmosphere loss
			IF APOAPSIS >= tarAlt {SET tset TO 0. }
			IF APOAPSIS < tarAlt {SET tset TO (tarAlt-APOAPSIS)/(tarAlt*0.01).}
		IF ALTITUDE > atmTop {
		SET runMode TO 3.
		}.
	}
	
	// circularization node and warp
    IF runMode = 3 {
        SET WARP TO 0.
		SET tset TO 0.
		MNV_APONODE(tarAlt, ETA:APOAPSIS).
		SET nodeDeltaV TO brnDV.
        SET runMode TO 4.
        scrollPrint("T+"+ROUND(MET(),1)+" Steering to maneuver node").
    }
 
 // One time check to decouple stage if nearly depleted
    IF runMode = 4 {
        SET tset TO 0.
        SET runMode TO 4.5.
        IF stageDeltaV > 0 { // dV alculator returns -1 if unable to calculate
            IF (stageDeltaV < nodeDeltaV*0.5 AND nodeDeltaV > 200) OR stageDeltaV < 100 {
                SET triggerStage TO True.
                scrollPrint("T+"+ROUND(MET(),1)+" Low fuel in stage, separating").
            }
        }
    }
	  
// Potential waiting on staging action if triggered
    IF runMode = 4.5 {
        SET tset TO 0.
        IF NOT (triggerStage OR stagingInProgress OR SHIP:MAXTHRUST < 0.01) {
            SET runMode TO 5.         
        }
    }
   
// Steer to maneuver node  
    IF runMode = 5 {
		MNV_WARPNODE(runMode, useWarp).
 		HUDTEXT(runmode, 5, 2, 15, red, false).
    }
   

// Apoapsis circularization maneuver execution 
    IF runMode = 8 {
		PRINT "Executing circularization burn" AT (17,0).
		MNV_EXENODE(runMode).
		IF runMode = 9 {
			SET launchComplete TO True.
		}    
    }
   
// Perform abort if determined necessary
    IF runMode = 666 {
        SET tset TO 0.
        SET SHIP:CONTROL:NEUTRALIZE TO True.
        SAS ON.
        TOGGLE ABORT.
        scrollPrint("T+"+ROUND(MET(),1)+" ~~~~~Launch aborted!~~~~~").
        HUDTEXT("Launch Aborted!",5,2,100,RED,False).
        BREAK.
    }
       
//Continuous staging check logic
    IF runMode > 0 {
        // Staging triggers
        IF (runMode = 1 OR runMode = 8) AND NOT stagingInProgress {
            // Engine flameout detection
            LIST ENGINES IN engList.
            FOR eng IN engList {
                IF NOT engIgnoreList:CONTAINS(eng:UID) {
                    // If flameout is just ullage motors stopping
                    IF eng:FLAMEOUT AND ullageDetect {
                        SET ullageShutdown TO True.
                        engIgnoreList:ADD(eng:UID).
                    }
                    // If flameout is due to a booster shutdown only
                    ELSE IF eng:FLAMEOUT AND MAXTHRUST >= 0.1 {
                        SET flameoutDetect TO True.
                        SET stagingInProgress TO True.
                        scrollPrint("T+"+ROUND(MET(),1)+" Booster shutdown detected").
                        SET boostStageTime TO TIME:SECONDS+boosterStageDelay.
                        BREAK.
                    }
                    // If flameout is entire stage engine shutdown
                    ELSE IF eng:FLAMEOUT AND MAXTHRUST < 0.1 {
                        SET flameoutDetect TO True.
                        SET stagingInProgress TO True.
                        SET tset TO 0.
                        scrollPrint("T+"+ROUND(MET(),1)+" Stage "+currentStageNum+" shutdown detected").
                        SET stageTime TO TIME:SECONDS+stageDelay.
                        BREAK. 
                    }
                }
            }
            IF ullageShutdown {            
                SET ullageDetect TO False.
                SET ullageShutdown TO False.
                scrollPrint("T+"+ROUND(MET(),1)+" Ullage shutdown").
            }
            // Drop tanks empty detection
            // IF NOT(flameoutDetect) {
                    // ## TODO
                    // SET dropTanksEmpty TO True.
            // }
        }
       
        // Staging triggered elsewhere in code
        IF triggerStage {
            SET tset TO 0.
            scrollPrint("T+"+ROUND(MET(),1)+" Staging triggered").
            SET stageTime TO TIME:SECONDS+stageDelay.
            SET triggerStage TO False.
            SET stagingInProgress TO True.
        }     
       
        // Booster staging (after specified delay)
        IF TIME:SECONDS >= boostStageTime {
            STAGE.
            SET numParts TO SHIP:PARTS:LENGTH.
            scrollPrint("T+"+ROUND(MET(),1)+" Booster separation").
            SET boostStageTime TO TIME:SECONDS+100000.
            SET stagingInProgress TO False.
        }
       
        // Full staging
        IF TIME:SECONDS >= stageTime {
            STAGE.
            SET numParts TO SHIP:PARTS:LENGTH.
            // drop tank release
            IF dropTanksEmpty {
                scrollPrint("T+"+ROUND(MET(),1)+" Drop tanks released").
                SET stageTime TO TIME:SECONDS+100000.
                SET dropTanksEmpty TO False.
            }
            // Detect ullage motor ignition
            SET stageSolidFuelMass TO 0.0075*STAGE:SOLIDFUEL.
            IF stageSolidFuelMass < 0.05*SHIP:MASS AND stageSolidFuelMass > 0 {
                SET ullageDetect TO True.
                scrollPrint("T+"+ROUND(MET(),1)+" Ullage motor ignition detected").
                LOCAL temp IS stageSolidInfo().
                SET ullageTime TO temp[0] + TIME:SECONDS.
                IF temp[0] = 99999 SET ullageDetect TO False. //should never happen, but just in case
                SET ullageThrust TO temp[1].
                LOCAL temp IS activeEngineInfo().
                IF temp[1] < ullageThrust*1.1 SET ullageStageNeeded TO True.
                SET stageTime TO TIME:SECONDS+100000.
            }
            // Detect separation only (ignition on the next stage)
            ELSE IF SHIP:MAXTHRUST < 0.01 {
                scrollPrint("T+"+ROUND(MET(),1)+" Stage "+currentStageNum+" separation").
                SET stageTime TO TIME:SECONDS+stageDelay.
            }  
            // Ignite next stage if already primed by separation action
            ELSE IF SHIP:MAXTHRUST >= 0.01 AND NOT ullageDetect {
                IF runMode = 1 OR runMode = 8 SET tset TO 1. // don't ignite if coasting
                SET currentStageNum TO currentStageNum+1.
                scrollPrint("T+"+ROUND(MET(),1)+" Stage "+currentStageNum+" ignition").
                SET stageTime TO TIME:SECONDS+100000.
                SET stagingInProgress TO False.
            }
        }
       
        // Ullage staging
        IF TIME:SECONDS >= (ullageTime - 1) { //start engines 1s before ullage engines stop
            IF ullageStageNeeded {
                WAIT UNTIL STAGE:READY.
                STAGE.
                SET ullageStageNeeded TO False.
            }
            IF runMode = 1 OR runMode = 8 SET tset TO 1.
            SET currentStageNum TO currentStageNum+1.
            scrollPrint("T+"+ROUND(MET(),1)+" Stage "+currentStageNum+" ignition").
            SET stageTime TO TIME:SECONDS+100000.
            SET ullageTime TO TIME:SECONDS+100000.
            SET stagingInProgress TO False.    
        }
    }
       
//Continuous abort detection logic
 
    IF allowAbort {
        // Angle to desired steering > 45deg (i.e. steering control loss)
        IF runMode = 1 {
            IF VANG(SHIP:FACING:VECTOR, steerTo:VECTOR) > 45 AND MET > 5 {
                SET runMode TO 666.
                scrollPrint("T+"+ROUND(MET(),1)+" Ship lost steering control!").
            }
        }
       
        // Abort if falling back toward surface (i.e. insufficient thrust)
        IF runMode < 3 AND runMode >= 0 AND VERTICALSPEED < -1.0 {
            SET runMode TO 666.
            scrollPrint("T+"+ROUND(MET(),1)+" Insufficient vertical velocity!").
        }
       
        // Abort if # parts less than expected (i.e. ship breaking up)
        IF SHIP:PARTS:LENGTH < numParts AND STAGE:READY {
            SET runMode TO 666.
            scrollPrint("T+"+ROUND(MET(),1)+" Ship breaking apart!").
        }
       
        // Abort if number of re-boost are too many (i.e. too shallow trajectory)
        IF numReboost > maxNumReboost {
            SET runMode TO 666.
            scrollPrint("T+"+ROUND(MET(),1)+" Too many re-boosts, trajectory poor").
        }
       
        // Perform abort if insufficient total deltaV vs deltaV to orbit ###TODO
    }
   
// Continuous informational printouts
    PRINT ROUND(ALTITUDE/1000,2)+" "   AT (8,4).
    SET downRangeDist TO SQRT(launchLoc:Distance^2 - (ALTITUDE-launchAlt)^2). // #@ should update to use curvature
    PRINT ROUND(downRangeDist/1000,2)+" " AT (25,4).
    PRINT ROUND(SHIP:OBT:INCLINATION,1)+"  " AT (44,4).
    PRINT ROUND(APOAPSIS/1000,2)+"   " AT (8,8).
    PRINT ROUND(ETA:APOAPSIS) + "s " AT (9,9).
    PRINT ROUND(PERIAPSIS/1000,2)+"  " AT (24,8).
    PRINT ROUND(ETA:PERIAPSIS) + "s " AT (26,9).
    SET engInfo TO activeEngineInfo().
    SET currentTWR TO engInfo[0]/(SHIP:MASS*BODY:MU/(ALTITUDE+BODY:RADIUS)^2).
    SET maxTWR TO engInfo[1]/(SHIP:MASS*BODY:MU/(ALTITUDE+BODY:RADIUS)^2).
    PRINT ROUND(currentTWR,2)+"   " AT (44,7).
    PRINT ROUND(maxTWR,2) + "  " AT (44,8).
    IF pctTerminalVel = "N/A" OR pctTerminalVel = "NoAcc" {
        PRINT runMode + "  " AT (44,9).
    }
    ELSE {
        PRINT ROUND(runmode,0) + "  " AT (44,9).
    }
    SET shipDeltaV TO "TBD". // ## TODO
    PRINT shipDeltaV AT (9,12).
    SET stageDeltaV TO deltaVStage().
    PRINT ROUND(stageDeltaV)+" " AT (26,12).
    IF lastDVTime < TIME:SECONDS AND finalBurnTime = 0 {
        SET dVSpent TO dVSpent + ((engInfo[0]/SHIP:MASS) * (TIME:SECONDS - lastDVTime)).
        SET lastDVTime TO TIME:SECONDS.
    }
    ELSE IF finalBurnTime > 0 {
        SET dVSpent TO dVSpent + ((engInfo[1]/SHIP:MASS) * finalBurnTime).
    }
    PRINT ROUND(dVSpent,0) + "   " AT (44,12).
   
//Periodic logging of progress
    IF TIME:SECONDS > logTime {
        printList:ADD("T+"+ROUND(MET(),0)+" Velocity = "+ROUND(VELOCITY:ORBIT:MAG,2)+" m/s").
        printList:ADD("      Altitude = "+ROUND(ALTITUDE/1000,2)+" km").
        scrollPrint("      Downrange distance = "+ROUND(downRangeDist/1000,2)+" km").
        IF runMode < 3 {SET logTime TO logTime + logTimeIncrement.}.
        ELSE IF runMode < 6 {SET logTime TO logTime + 2*logTimeIncrement.}.
        ELSE SET logTime TO logTime + 4*logTimeIncrement.
    } 
   
// Verbose data logging if requested
    IF logVerboseData and TIME:SECONDS >= verboseLogTime { 
    LOG MET()+", "+ALTITUDE+", "+ALT:RADAR+", "+LATITUDE+", "+LONGITUDE+", "+SHIP:AIRSPEED+", "+VELOCITY:ORBIT:MAG+", "+VERTICALSPEED+", "+GROUNDSPEED+", "+APOAPSIS+", "+ETA:APOAPSIS+", "+PERIAPSIS+", "+ETA:PERIAPSIS+", "+SHIP:OBT:INCLINATION+", "+SHIP:MASS+", "+engInfo[1]+", "+engInfo[0]+", "+currentTWR+", "+pctTerminalVel+", "+trajectoryPitch+", "+steerPitch+", "+pitch_for(SHIP)+", "+steerHeading+", "+compass_for(SHIP)+", "+dVSpent+", " TO launchDataLog.csv.
    SET verboseLogTime TO TIME:SECONDS + verboseLogIncrement.
    }
}
// Main loop end
 
SET tset TO 0.
UNLOCK STEERING.
 
IF launchComplete {
    REMOVE burnNode.
    printList:ADD("T+"+ROUND(MET(),1)+" Orbit achieved").
    printList:ADD("-------------------------------------------").
    printList:ADD(" Final apoapsis = "+ROUND(APOAPSIS/1000,2)+
        " km, Error = "+ROUND(ABS(tarAlt-APOAPSIS)/1000,2)+" km").
    printList:ADD(" Final periapsis = "+ROUND(PERIAPSIS/1000,2)+
        " km, Error = "+ROUND(ABS(tarAlt-PERIAPSIS)/1000,2)+" km").
    printList:ADD(" Final inclination = "+ROUND(SHIP:OBT:INCLINATION,1)+
        " deg, Error = "+ROUND(ABS(ABS(tarInc)-SHIP:OBT:INCLINATION),1)+" deg").
    printList:ADD(" Total dV spent = "+ROUND(dVSpent)+" m/s").
    printList:ADD("-------------------------------------------").
    scrollPrint("Program ended successfully").
}
ELSE {
    scrollPrint("Program terminating").
}

FUNCTION END_LAUNCH {
    IF launchComplete {
	REMOVE burnNode.
    printList:ADD("T+"+ROUND(MET(),1)+" Orbit achieved").
    printList:ADD("-------------------------------------------").
    printList:ADD(" Final apoapsis = "+ROUND(APOAPSIS/1000,2)+
        " km, Error = "+ROUND(ABS(tarAlt-APOAPSIS)/1000,2)+" km").
    printList:ADD(" Final periapsis = "+ROUND(PERIAPSIS/1000,2)+
        " km, Error = "+ROUND(ABS(tarAlt-PERIAPSIS)/1000,2)+" km").
    printList:ADD(" Final inclination = "+ROUND(SHIP:OBT:INCLINATION,1)+
        " deg, Error = "+ROUND(ABS(ABS(tarInc)-SHIP:OBT:INCLINATION),1)+" deg").
    printList:ADD(" Total dV spent = "+ROUND(dVSpent)+" m/s").
    printList:ADD("-------------------------------------------").
    scrollPrint("Program ended successfully").
	}
	ELSE {
		scrollPrint("Program terminating").
	}
}
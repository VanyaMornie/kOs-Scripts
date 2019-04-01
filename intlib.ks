//Intercept library 
//REQUIRE("bodylib.ks"). //get properties of the body you're launching from
//REQUIRE("nodelib.ks").

FUNCTION tgtType {
	PARAMETER tgt.
		LIST TARGETS IN vess.
		FOR vs IN vess {
			IF vs:NAME = tgt {
				RETURN VESSEL(tgt).
			}
		}
		RETURN BODY(tgt).
	}
	
FUNCTION TRANS_TIME {
	PARAMETER tgtAlt.
	SET r1 TO rb + ALTITUDE.
	SET r2 TO tgtAlt.
	SET dv1 TO SQRT(mu / r1) * (SQRT((2 * r2) / (r1 + r2)) - 1).
	SET dv2 TO SQRT(mu / r2) * (1 - SQRT((2 * r1) / (r1 + r2))).
	SET trTime TO cpi * SQRT((r1 + r2)^3 / (8 * mu)).
	scrollPrint("T+"+ROUND(mTime,1)+" Transfer time to "+tgt+" - "+trTime+"s").
	RETURN trTime.
	}
FUNCTION PHASE_ANGLE {
    PARAMETER object1,object2.//measures the phase of object2 as seen from object 1
    LOCAL localBodyPos IS object1:BODY:POSITION.
    LOCAL vecBodyToC1 IS (object1:POSITION - localBodyPos):NORMALIZED.
    LOCAL vecBodyToC2 IS VXCL(normal_of_orbit(object1),(object2:POSITION - localBodyPos):NORMALIZED):NORMALIZED.//orbit normal is excluded to remove any inclination from calculation
    LOCAL phaseAngle IS VANG(vecBodyToC1,vecBodyToC2).
    IF VDOT(vecBodyToC2,VXCL(UP:VECTOR,object1:VELOCITY:ORBIT):NORMALIZED) < 0 {//corrects for if object2 is ahead or behind object1
        SET phaseAngle TO 360 - phaseAngle.
    }
    RETURN phaseAngle.
}

FUNCTION normal_of_orbit {//returns the normal of a crafts/bodies orbit, will point north if orbiting clockwise on equator
    PARAMETER object.
    RETURN VCRS(object:VELOCITY:ORBIT:NORMALIZED, (object:BODY:POSITION - object:POSITION):NORMALIZED):NORMALIZED.
}
	
FUNCTION INT_HOH {
	PARAMETER tgt.
	PARAMETER ang IS 0. //desired orbital intercept angle. 0 for direct intercept.
	//SET tgt TO TGTTYPE(tgt).
	SET tgtR TO tgt:OBT:SEMIMAJORAXIS.
	SET tgtAlt TO (tgt:OBT:SEMIMAJORAXIS)-rb.
	PRINT tgtAlt.
	TTIME(tgtR).
	PRINT "Transit Time:" + ROUND(trTime).
	SET tgtPer TO tgt:OBT:PERIOD.
	SET shpPer TO SHIP:OBT:PERIOD.
	SET tgtAn TO tgt:OBT:TRUEANOMALY.
	SET shpAn TO SHIP:OBT:TRUEANOMALY.
	SET tgtW TO 360/tgtPer.
	SET shpW TO 360/shpPer.
	SET dAng TO tgtW*trTime.
	SET phAng TO (tgtAn - shpAn) - dAng + intAng.
	SET curAng TO (360-tgtAn)-shpAn.
	SET trWs TO shpW-tgtW.
	SET ttAng TO ABS(dAng/trWs).
	PRINT "T+"+mTime+" Intercept targeted with "+intAng+"deg shift".
	SET msg TO "T+"+mTime+" Transfer burn in "+ttAng+"s".
	PRINT msg.
	NOTIFY(msg).
	SET nd TO NODE(TIME:SECONDS+ttAng,0,0,dv1).
	ADD nd.
	MNV_EX_NODE(TRUE).
	MNV_APONODE(TRUE, tgtAlt).
	MNV_EX_NODE(TRUE).
	}
		
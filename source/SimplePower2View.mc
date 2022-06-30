import Toybox.Activity;
import Toybox.Application.Properties;
import Toybox.Lang;
import Toybox.Math;
import Toybox.Time;
import Toybox.WatchUi;

class SimplePower2View extends WatchUi.SimpleDataField {

    hidden var grade as differentiate;
    hidden var acc as differentiate;

    hidden var mMass as Float;
    hidden var mCwA as Float;
    hidden var mRho as Float;
    hidden var mDtLoss as Float;

    // Set the label of the data field here.
    function initialize() {
        SimpleDataField.initialize();
        label = "est. Power/W";
        grade = new Differentiate();
        acc = new Differentiate();

        onSettingsChanged();
    }

    public function onSettingsChanged() as Void {
        mMass = Properties.getValue("mass_prop") as Float;
        mCwA = Properties.getValue("CwA_prop") as Float;
        mRho = Properties.getValue("Rho_prop") as Float;
        mDtLoss = Properties.getValue("dtLoss_prop") as Float;
    }

    //function getSettingsView() {
    //    return [new AnalogSettingsView(), new AnalogSettingsDelegate()];
    //}

    // The given info object contains all the current workout
    // information. Calculate a value and return it in this method.
    // Note that compute() and onUpdate() are asynchronous, and there is no
    // guarantee that compute() will be called before onUpdate().
    function compute(info as Activity.Info) as Numeric or Duration or String or Null {
        // See Activity.Info in the documentation for available information.
        // See Activity.Info in the documentation for available information.
        if(info has :altitude){
            if(info.altitude != null){
                var altitude = info.altitude as Float;
                if(info has :elapsedDistance){
                    if(info.elapsedDistance != null){
                        var distance = info.elapsedDistance as Float;
                        if(info has :currentSpeed){
                            if(info.currentSpeed != null){
                                var speed = info.currentSpeed as Float;
                                if(info has :elapsedTime){
                                    if(info.elapsedTime != null){
                                        var time = (info.elapsedTime as Float)/1000.0;
                                        return calcPower(time, speed, distance, altitude);
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        return null;
    }

    function calcPower(time as Float, speed as Float, dist as Float, alt as Float) as Float {
        var gr= grade.add(dist, alt);
        var ac =acc.add(time, speed);
        speed=acc.yMean();
        var angle=Math.atan(gr);
        var F_grav=9.81*Math.sin(angle)*mMass;
        var F_drag=0.5*mCwA*mRho*speed*speed;
        var F_sum=F_grav+F_drag + ac*mMass;
        var P_Wheel=F_sum*speed;
        if (P_Wheel<0) {
            return P_Wheel;
        } else {
            return P_Wheel/(1-mDtLoss/100);
        }
    }
}

const difSize = 10;

class Differentiate {
    protected var mPos as Number = 0;
    protected var mLastX as Float = 0;
    protected var mIsFilled = false;
    protected var mNoLastX = true;
    protected var mX as Array<Float> = new Array<Float>[difSize];
    protected var mY as Array<Float> = new Array<Float>[difSize];

    protected var mSumX as Float = 0;
    protected var mSumY as Float = 0;
    protected var mSumXY as Float = 0;
    protected var mSumX2 as Float = 0;
    protected var mMax as Float = 0;

    function add(ax as Float, ay as Float) as Float {
        if (mNoLastX || ax>mLastX) {
            addValues(ax,ay);
        }
        mLastX=ax;
        mNoLastX=false;
 
        if (mIsFilled) {
            var denom = difSize * mSumX2 - mSumX * mSumX;
            var numer = difSize * mSumXY - mSumX * mSumY;
            if (abs(denom)<1e-5) {
                return mMax*sign(numer)*sign(denom);
            } else {
                var d = numer / denom;
                var ad = abs(d);
                if (ad>mMax) {
                    mMax=ad;
                }
                return d;
            }
        } else {
            return 0;
        }
    }

    function addValues(ax as Float, ay as Float) {
        if (mIsFilled) {
            var oldX=mX[mPos];
            var oldY=mY[mPos];
            mSumX=mSumX-oldX;
            mSumY=mSumY-oldY;
            mSumXY=mSumXY-oldX*oldY;
            mSumX2=mSumX2-oldX*oldX;
        }
        mX[mPos]=ax;
        mY[mPos]=ay;

        mSumX=mSumX+ax;
        mSumY=mSumY+ay;
        mSumXY=mSumXY+ax*ay;
        mSumX2=mSumX2+ax*ax;

        mPos=mPos+1;
        if (mPos==difSize) {
            mPos=0;
            mIsFilled=true;
        }
    }

    function xMean() as Float {
        return mSumX/difSize;
    }

    function yMean() as Float {
        return mSumY/difSize;
    }

}

function sign(x as Float) as Float {
    if (x<0) {
        return -1;
    }
    return 1;
}

function abs(x as Float) as Float {
    if (x<0) {
        return -x;
    }
    return x;
}

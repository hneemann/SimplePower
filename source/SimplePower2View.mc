import Toybox.Activity;
import Toybox.Application.Properties;
import Toybox.Lang;
import Toybox.Math;
import Toybox.Time;
import Toybox.WatchUi;

class SimplePower2View extends WatchUi.SimpleDataField {

    hidden var grade as Differentiate;
    hidden var acc as Differentiate;
    hidden var delaySpeed as Delay;
    hidden var delayAcc as Delay;
    hidden var mValid as Boolean;

    hidden var mMass as Float;
    hidden var mCwA as Float;
    hidden var mRho as Float;
    hidden var mCrr as Float;
    hidden var mDtLoss as Float;

    // Set the label of the data field here.
    function initialize() {
        SimpleDataField.initialize();
        label = "est. Power/W";
        grade = new Differentiate(15);
        acc = new Differentiate(15);
        delayAcc = new Delay(10);
        delaySpeed = new Delay(10);

        onSettingsChanged();
    }

    public function onSettingsChanged() as Void {
        mMass = Properties.getValue("mass_prop") as Float;
        mCwA = Properties.getValue("CwA_prop") as Float;
        mRho = Properties.getValue("Rho_prop") as Float;
        mDtLoss = Properties.getValue("dtLoss_prop") as Float;
        mCrr = Properties.getValue("Crr_prop") as Float / 100;
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
        if (info has :altitude) {
            if (info.altitude != null) {
                var altitude = info.altitude as Float;
                if (info has :elapsedDistance) {
                    if (info.elapsedDistance != null) {
                        var distance = info.elapsedDistance as Float;
                        if (info has :currentSpeed) {
                            if (info.currentSpeed != null) {
                                var speed = info.currentSpeed as Float;
                                if (info has :elapsedTime) {
                                    if (info.elapsedTime != null) {
                                        var time = (info.elapsedTime as Float)/1000.0;
                                        var p = calcPower(time, speed, distance, altitude).toNumber();

                                        if (info has :currentCadence) {
                                            if (info.currentCadence != null) {
                                                var cad = info.currentCadence as Lang.Number;
                                                if (cad<10) {
                                                    return 0;
                                                }
                                            }
                                        }
                                        if (p<0) {
                                            p=0;
                                        }

                                        return p;
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        return 0;
    }

    function calcPower(time as Float, speed as Float, dist as Float, alt as Float) as Float {
        var gr = grade.add(dist, alt);
        var ac = delayAcc.delay(acc.add(time, speed));
        var delayedSpeed=delaySpeed.delay(acc.yMean());
        var F_g    = 9.81*mMass;
        var F_grav = sinatan(gr)*F_g;
        var F_rol  = cosatan(gr)*F_g*mCrr;
        var F_drag = 0.5*mCwA*mRho*delayedSpeed*delayedSpeed;
        var F_acc  = ac*mMass;
        var F_sum  = F_grav + F_drag + F_acc + F_rol;
        mValid = abs(F_grav)>(abs(F_drag)+abs(F_acc))*4;
        var P_Wheel = F_sum*delayedSpeed;
        if (P_Wheel<0) {
            return P_Wheel;
        } else {
            return P_Wheel/(1-mDtLoss/100);
        }
    }
}

class Delay {
    protected var mSize as Number;
    protected var mX as Array<Float>;
    protected var mPos as Number = 0;
    protected var mNoData as Boolean = true;

    function initialize(n as Number) {
        mX = new Array<Float>[n];
        mSize = n;
    }

    function delay(ax as Float) as Float {
        if (mNoData) {
            mNoData=false;
            for (var i = 0; i < mSize; i += 1) {
                mX[i]=ax;
            }
            return ax;
        }

        var ret = mX[mPos];
        mX[mPos] = ax;

        mPos=mPos+1;
        if (mPos==mSize) {
            mPos=0;
        }

        return ret;
    }

}


class Differentiate {
    protected var mPos as Number = 0;
    protected var mSize as Number;
    protected var mLastX as Float = 0;
    protected var mIsFilled = false;
    protected var mNoLastX = true;
    protected var mX as Array<Float>;
    protected var mY as Array<Float>;

    protected var mSumX as Double = 0;
    protected var mSumY as Double = 0;
    protected var mSumXY as Double = 0;
    protected var mSumX2 as Double = 0;
    protected var mMax as Float = 0;

    function initialize(n as Number) {
        mX = new Array<Float>[n];
        mY = new Array<Float>[n];
        mSize = n;
    }

    function add(ax as Float, ay as Float) as Float {
        if (mNoLastX || ax>mLastX) {
            addValues(ax,ay);
            mLastX=ax;
            mNoLastX=false;
        }
 
        if (mIsFilled) {
            var numer = mSize * mSumXY - mSumX * mSumY;
            var denom = mSize * mSumX2 - mSumX * mSumX;
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
            var oldX=mX[mPos].toDouble();
            var oldY=mY[mPos].toDouble();
            mSumX=mSumX-oldX;
            mSumY=mSumY-oldY;
            mSumXY=mSumXY-oldX*oldY;
            mSumX2=mSumX2-oldX*oldX;
        }
        mX[mPos]=ax;
        mY[mPos]=ay;

        var axd = ax.toDouble();
        var ayd = ay.toDouble();

        mSumX=mSumX+axd;
        mSumY=mSumY+ayd;
        mSumXY=mSumXY+axd*ayd;
        mSumX2=mSumX2+axd*axd;

        mPos=mPos+1;
        if (mPos==mSize) {
            mPos=0;
            mIsFilled=true;
        }
    }

    function xMean() as Float {
        return mSumX/mSize;
    }

    function yMean() as Float {
        return mSumY/mSize;
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

// 3. order Taylor series of sin(atan(x))
function sinatan(x as Float) as Float {
    return x-(x*x*x)/2;
}

// 2. order Taylor series of cos(atan(x))
function cosatan(x as Float) as Float {
    return 1-(x*x)/2;
}

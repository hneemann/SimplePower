import Toybox.Activity;
import Toybox.Application.Properties;
import Toybox.Lang;
import Toybox.Math;
import Toybox.Time;
import Toybox.WatchUi;

class SimplePower2View extends WatchUi.DataField {
    private const BORDER_PAD = 4;
    private const UNITS_SPACING = 2;

    private const _fonts as Array<FontDefinition> = [Graphics.FONT_XTINY, Graphics.FONT_TINY, Graphics.FONT_SMALL, Graphics.FONT_MEDIUM, Graphics.FONT_LARGE,
             Graphics.FONT_NUMBER_MILD, Graphics.FONT_NUMBER_MEDIUM, Graphics.FONT_NUMBER_HOT, Graphics.FONT_NUMBER_THAI_HOT] as Array<FontDefinition>;

    // Label Variables
    private const _labelString = "est. Power";
    private const _labelFont = Graphics.FONT_SMALL;
    private var _labelX as Number = 0;

    // Font values
    private const _unitsFont = Graphics.FONT_TINY;
    private var _dataFont as FontDefinition = Graphics.FONT_XTINY;
    private var _dataFontAscent as Number = 0;

    // Power variables
    private const _pwUnitsString = "W";
    private const _pwUnitsStringError = "W?";
    private var _pwUnitsWidth as Number?;
    private var _pwX as Number = 0;
    private var _pwY as Number = 0;


    hidden var grade as Differentiate;
    hidden var acc as Differentiate;
    hidden var delaySpeed as Delay;
    hidden var delayAcc as Delay;
    hidden var dataValid as Boolean = false;
    hidden var largeError as Boolean = false;
    hidden var power as Number = 0;

    hidden var mMass as Float;
    hidden var mCwA as Float;
    hidden var mRho as Float;
    hidden var mCrr as Float;
    hidden var mDtLoss as Float;

    // Set the label of the data field here.
    function initialize() {
        DataField.initialize();
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

    //! Load your resources here
    //! @param dc Device context
    public function onLayout(dc as Dc) as Void {
        var width = dc.getWidth();
        var height = dc.getHeight();
        var top = Graphics.getFontAscent(_labelFont) + BORDER_PAD;

        // Units width does not change, compute only once
        if (_pwUnitsWidth == null) {
            _pwUnitsWidth = dc.getTextWidthInPixels(_pwUnitsStringError, _unitsFont) + UNITS_SPACING;
        }
        var pwUnitsWidth = _pwUnitsWidth as Number;

        // Center the field label
        _labelX = width / 2;

        // Compute data position
        var LayoutWidth = width - (2 * BORDER_PAD) - pwUnitsWidth;
        var LayoutHeight = height - (2 * BORDER_PAD) - top;
        var LayoutFontIdx = selectFont(dc, LayoutWidth, LayoutHeight);

        _dataFont = _fonts[LayoutFontIdx];
        _dataFontAscent = Graphics.getFontAscent(_dataFont);

        // Compute the draw location of the Power Value
        var textWidth = dc.getTextWidthInPixels("1000", _dataFont);
         _pwX = BORDER_PAD + (LayoutWidth / 2) + (textWidth / 2);
         _pwY = (height - top) / 2 + top - (_dataFontAscent / 2);
    }

    //! Get the largest font that fits in the given width and height
    //! @param dc Device context
    //! @param width Width to fit in
    //! @param height Height to fit in
    //! @return Index of the font that fits
    private function selectFont(dc as Dc, width as Number, height as Number) as Number {
        var testString = "1000"; // Dummy string to test data width
        var fontIdx;
        // Search through fonts from biggest to smallest
        for (fontIdx = (_fonts.size() - 1); fontIdx > 0; fontIdx--) {
            var dimensions = dc.getTextDimensions(testString, _fonts[fontIdx]);
            if ((dimensions[0] <= width) && (dimensions[1] <= height)) {
                // If this font fits, it is the biggest one that does
                break;
            }
        }

        return fontIdx;
    }

    //! Handle the update event
    //! @param dc Device context
    public function onUpdate(dc as Dc) as Void {
        var bgColor = getBackgroundColor();
        var fgColor = Graphics.COLOR_WHITE;

        if (bgColor == Graphics.COLOR_WHITE) {
            fgColor = Graphics.COLOR_BLACK;
        }

        dc.setColor(fgColor, bgColor);
        dc.clear();

        dc.setColor(fgColor, Graphics.COLOR_TRANSPARENT);

        // Draw the field label
        dc.drawText(_labelX, 0, _labelFont, _labelString, Graphics.TEXT_JUSTIFY_CENTER);

        // Update status
        var powerStr = "____";
        if (dataValid) {
            powerStr=power.format("%d");
        }

        // Draw Power Value
        dc.drawText(_pwX, _pwY, _dataFont, powerStr, Graphics.TEXT_JUSTIFY_RIGHT);
        var x = _pwX + UNITS_SPACING;
        var y = _pwY + _dataFontAscent - Graphics.getFontAscent(_unitsFont);


        if (largeError) {
            dc.drawText(x, y, _unitsFont, _pwUnitsStringError, Graphics.TEXT_JUSTIFY_LEFT);
        } else {
            dc.drawText(x, y, _unitsFont, _pwUnitsString, Graphics.TEXT_JUSTIFY_LEFT);
        }
    }

    //function getSettingsView() {
    //    return [new AnalogSettingsView(), new AnalogSettingsDelegate()];
    //}

    // The given info object contains all the current workout
    // information. Calculate a value and return it in this method.
    // Note that compute() and onUpdate() are asynchronous, and there is no
    // guarantee that compute() will be called before onUpdate().
    public function compute(info as Activity.Info) as Void {
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
                                                    p = 0;
                                                    largeError=false;
                                                }
                                            }
                                        }
                                        if (p<0) {
                                            p=0;
                                        }

                                        power=p;
                                        dataValid=true;
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
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
        largeError = abs(F_grav)<(abs(F_drag)+abs(F_acc))*4;
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

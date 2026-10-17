import Toybox.Application;
import Toybox.Lang;
import Toybox.Math;

// Display formatting of the cached Trading212/Yahoo values (see StonksData for the cache layout)
module StonksFormat {
    const TYPE_VALUE = 79;
    const TYPE_PL = 80;
    const TYPE_PL_PCT = 81;
    const NO_DATA = "---";

    // Steps used to make a number fit the field: 1 decimal, no decimals, then thousands (K) and millions (M)
    const DIVIDERS = [1.0, 1.0, 1000.0, 1000.0, 1000000.0, 1000000.0];
    const DECIMALS = [1, 0, 1, 0, 1, 0];
    const SUFFIXES = ["", "", "K", "K", "M", "M"];

    function isStonksType(type as Number) as Boolean {
        return type >= TYPE_VALUE and type <= TYPE_PL_PCT;
    }

    function getValue(type as Number, width as Number, cache as Array?) as String {
        if(cache == null) { return NO_DATA; }
        if(type == TYPE_VALUE) {
            return fit(cache[StonksData.C_TOTAL] as Float, width, false, 1);
        }
        if(cache[StonksData.C_PL] == null) { return NO_DATA; }
        if(type == TYPE_PL) {
            return fit(cache[StonksData.C_PL] as Float, width, true, 0);
        }
        return percent(cache[StonksData.C_PL_PCT] as Float, width);
    }

    // Label sizes: 1 = short, 2 = medium, 3+ = long
    function getLabel(type as Number, size as Number, cache as Array?) as String {
        var currency = (cache != null) ? " " + cache[StonksData.C_CURRENCY] : "";
        if(type == TYPE_VALUE) {
            if(size <= 1) { return Application.loadResource(Rez.Strings.LABEL_PORT) + ":"; }
            if(size == 2) { return Application.loadResource(Rez.Strings.LABEL_PORT) + currency + ":"; }
            return Application.loadResource(Rez.Strings.LABEL_PORTFOLIO) + currency + ":";
        }
        if(type == TYPE_PL) {
            if(size <= 1) { return Application.loadResource(Rez.Strings.LABEL_PL) + ":"; }
            if(size == 2) { return Application.loadResource(Rez.Strings.LABEL_PL) + currency + ":"; }
            return Application.loadResource(Rez.Strings.LABEL_DAYPL) + currency + ":";
        }
        if(size <= 2) { return Application.loadResource(Rez.Strings.LABEL_PLPCT) + ":"; }
        return Application.loadResource(Rez.Strings.LABEL_DAYPLPCT) + ":";
    }

    // Money with 1 decimal (signed) shrunk step by step until it fits the width, e.g. +123.4, +123, +1K, +1.2K
    function fit(value as Float, width as Number, signed as Boolean, first as Number) as String {
        var str = "";
        for(var i = first; i < DIVIDERS.size(); i++) {
            str = scale(value, i, signed);
            if(str.length() <= width) { return str; }
        }
        return str;
    }

    function scale(value as Float, step as Number, signed as Boolean) as String {
        var factor = (DECIMALS[step] == 1) ? 10.0 : 1.0;
        var rounded = Math.round(value / DIVIDERS[step] * factor) / factor;
        var str = (DECIMALS[step] == 1) ? rounded.abs().format("%.1f") : rounded.abs().toNumber().format("%d");
        if(step >= 4 and str.length() > 2 and str.substring(0, 2).equals("0.")) {
            str = str.substring(1, str.length());
        }
        var sign = (rounded < 0.0) ? "-" : (signed ? "+" : "");
        return sign + str + SUFFIXES[step];
    }

    // Unsigned percent with 1 decimal and no percent sign (the label shows it), e.g. 1.2
    function percent(value as Float, width as Number) as String {
        var abs = value.abs();
        var str = (Math.round(abs * 10.0) / 10.0).format("%.1f");
        if(str.length() <= width) { return str; }
        return Math.round(abs).toNumber().format("%d");
    }
}

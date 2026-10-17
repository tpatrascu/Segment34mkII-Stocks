import Toybox.Lang;
import Toybox.Time;

// Helpers shared by the foreground and the background service.
// Cached result layout (stored as an Array): [timestamp, currency, totalValue, dailyPL, dailyPLPercent]
// dailyPL and dailyPLPercent are null when the P/L could not be calculated.
(:background)
module StonksData {
    const CACHE_KEY = "stonks";
    const CACHE_SIZE = 5;
    const C_TIME = 0;
    const C_CURRENCY = 1;
    const C_TOTAL = 2;
    const C_PL = 3;
    const C_PL_PCT = 4;

    const MARKET_US = 0;
    const MARKET_EU = 1;
    const MARKET_ALWAYS = 2;

    const EXCHANGE_LETTERS = "ldapems";
    const EXCHANGE_SUFFIXES = [".L", ".DE", ".AS", ".PA", ".MC", ".MI", ".SW"];

    // Trading212 ticker (AAPL_US_EQ, VODl_EQ, SAPd_EQ, ...) -> Yahoo Finance symbol (AAPL, VOD.L, SAP.DE, ...)
    function yahooSymbol(ticker as String) as String {
        var us = ticker.find("_US_EQ");
        var base = ticker;
        var suffix = "";
        if(us != null) {
            base = ticker.substring(0, us);
        } else {
            var eq = ticker.find("_EQ");
            if(eq == null or eq < 2) { return ticker; }
            base = ticker.substring(0, eq);
            var last = base.substring(eq - 1, eq);
            var idx = EXCHANGE_LETTERS.find(last);
            if(idx != null) {
                base = base.substring(0, eq - 1);
                suffix = EXCHANGE_SUFFIXES[idx];
            }
        }
        var u = base.find("_");
        if(u != null) { base = base.substring(0, u) + "-" + base.substring(u + 1, base.length()); }
        return base + suffix;
    }

    // Change in position value (account currency) since the previous close.
    // Only the price ratio is used, so the instrument currency/unit (e.g. GBX vs GBP) does not matter.
    function dailyChange(value as Float, price as Float, prevClose as Float) as Float {
        if(price <= 0.0 or prevClose <= 0.0) { return 0.0; }
        return value * (1.0 - prevClose / price);
    }

    // Day of week, 0 = Sunday
    function dayOfWeek(year as Number, month as Number, day as Number) as Number {
        var t = [0, 3, 2, 5, 0, 3, 5, 1, 4, 6, 2, 4];
        if(month < 3) { year -= 1; }
        return (year + year / 4 - year / 100 + year / 400 + t[month - 1] + day) % 7;
    }

    // US: second Sunday of March until first Sunday of November
    function isUsDst(year as Number, month as Number, day as Number) as Boolean {
        if(month > 3 and month < 11) { return true; }
        if(month == 3) { return day >= 8 + (7 - dayOfWeek(year, 3, 8)) % 7; }
        if(month == 11) { return day < 1 + (7 - dayOfWeek(year, 11, 1)) % 7; }
        return false;
    }

    // EU: last Sunday of March until last Sunday of October
    function isEuDst(year as Number, month as Number, day as Number) as Boolean {
        if(month > 3 and month < 10) { return true; }
        if(month == 3) { return day >= 31 - dayOfWeek(year, 3, 31); }
        if(month == 10) { return day < 31 - dayOfWeek(year, 10, 31); }
        return false;
    }

    // US: 09:30-16:00 New York time, EU: 09:00-17:30 Central European time, Monday to Friday. Holidays are not considered.
    function isMarketOpen(market as Number) as Boolean {
        if(market == MARKET_ALWAYS) { return true; }
        var t = Time.Gregorian.utcInfo(Time.now(), Time.FORMAT_SHORT);
        if(t.day_of_week == 1 or t.day_of_week == 7) { return false; }

        var open = 0;
        var close = 0;
        if(market == MARKET_US) {
            open = isUsDst(t.year, t.month, t.day) ? 13 * 60 + 30 : 14 * 60 + 30;
            close = open + 6 * 60 + 30;
        } else {
            open = isEuDst(t.year, t.month, t.day) ? 7 * 60 : 8 * 60;
            close = open + 8 * 60 + 30;
        }
        var now = t.hour * 60 + t.min;
        return now >= open and now < close;
    }
}

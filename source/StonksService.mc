import Toybox.Application;
import Toybox.Background;
import Toybox.Communications;
import Toybox.Lang;
import Toybox.StringUtil;
import Toybox.System;
import Toybox.Time;

// Background process: fetches the account summary and positions from Trading212 and the previous
// close of every position from Yahoo Finance, and hands [time, currency, total, dailyPL, dailyPLPercent]
// to the foreground (see StonksData). Always exits with an Array so the foreground can reschedule.
(:background)
class StonksServiceDelegate extends System.ServiceDelegate {
    const QUOTES_PER_REQUEST = 10;
    const YAHOO_URL = "https://query1.finance.yahoo.com/v8/finance/spark?range=1d&interval=1d&symbols=";

    hidden var mAuth as Dictionary = {};
    hidden var mBaseUrl as String = "";
    hidden var mCurrency as String = "";
    hidden var mTotal as Float = 0.0;
    hidden var mHoldings as Dictionary = {};
    hidden var mSymbols as Array = [];
    hidden var mNext as Number = 0;
    hidden var mPl as Float = 0.0;
    hidden var mPlOk as Boolean = true;

    function initialize() {
        ServiceDelegate.initialize();
    }

    function onTemporalEvent() as Void {
        var p = Application.Properties;
        var key = p.getValue("t212ClientId") as String;
        var secret = p.getValue("t212SecretKey") as String;
        var hasCache = Application.Storage.getValue(StonksData.CACHE_KEY) != null;
        if(key.length() == 0 or secret.length() == 0 or (hasCache and !StonksData.isMarketOpen(p.getValue("stonksMarket") as Number))) {
            Background.exit([]);
            return;
        }

        mAuth = {"Authorization" => "Basic " + StringUtil.encodeBase64(key + ":" + secret)};
        mBaseUrl = ((p.getValue("t212Account") as Number) == 1 ? "https://live" : "https://demo") + ".trading212.com/api/v0/equity/";
        request(mBaseUrl + "account/summary", mAuth, method(:onSummary));
    }

    hidden function request(url as String, headers as Dictionary, callback as Method) as Void {
        Communications.makeWebRequest(url, null, {
            :method => Communications.HTTP_REQUEST_METHOD_GET,
            :headers => headers,
            :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
        }, callback);
    }

    function onSummary(code as Number, data as Dictionary or String or Null) as Void {
        if(code != 200 or !(data instanceof Dictionary) or data["totalValue"] == null) {
            Background.exit([]);
            return;
        }
        mTotal = (data["totalValue"] as Number or Float).toFloat();
        mCurrency = data["currency"] as String;
        request(mBaseUrl + "positions", mAuth, method(:onPositions));
    }

    function onPositions(code as Number, data as Dictionary or String or Array or Null) as Void {
        if(code != 200 or !(data instanceof Array)) {
            finish(false);
            return;
        }

        for(var i = 0; i < data.size(); i++) {
            var position = data[i] as Dictionary;
            var instrument = position["instrument"] as Dictionary?;
            var wallet = position["walletImpact"] as Dictionary?;
            if(instrument == null or wallet == null or wallet["currentValue"] == null) { continue; }
            var symbol = StonksData.yahooSymbol(instrument["ticker"] as String);
            var value = (wallet["currentValue"] as Number or Float).toFloat();
            var held = mHoldings[symbol];
            mHoldings[symbol] = (held == null) ? value : held + value;
        }
        data = null;

        mSymbols = mHoldings.keys();
        requestQuotes();
    }

    hidden function requestQuotes() as Void {
        if(mNext >= mSymbols.size()) {
            finish(mPlOk);
            return;
        }

        var end = mNext + QUOTES_PER_REQUEST;
        if(end > mSymbols.size()) { end = mSymbols.size(); }
        var list = mSymbols[mNext] as String;
        for(var i = mNext + 1; i < end; i++) { list += "," + mSymbols[i]; }
        mNext = end;
        request(YAHOO_URL + list, {"User-Agent" => "Mozilla/5.0"}, method(:onQuotes));
    }

    // Symbols Yahoo does not know are left out of the response (a request with only unknown symbols returns 404).
    // Their positions simply count as unchanged.
    function onQuotes(code as Number, data as Dictionary or String or Array or Null) as Void {
        if(code == 200 and data instanceof Dictionary) {
            var symbols = data.keys();
            for(var i = 0; i < symbols.size(); i++) {
                var quote = data[symbols[i]] as Dictionary?;
                var value = mHoldings[symbols[i]];
                if(quote == null or value == null) { continue; }
                var price = quote["fulldayPrice"];
                var prevClose = quote["chartPreviousClose"];
                if(price == null or prevClose == null) { continue; }
                mPl += StonksData.dailyChange(value as Float, (price as Number or Float).toFloat(), (prevClose as Number or Float).toFloat());
            }
        } else if(code != 404) {
            mPlOk = false;
        }
        requestQuotes();
    }

    hidden function finish(withPl as Boolean) as Void {
        var pl = null;
        var pct = null;
        if(withPl) {
            var prevTotal = mTotal - mPl;
            pl = mPl;
            pct = (prevTotal > 0.0) ? mPl / prevTotal * 100.0 : 0.0;
        }
        Background.exit([Time.now().value(), mCurrency, mTotal, pl, pct]);
    }
}

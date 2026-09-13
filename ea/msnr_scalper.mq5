//+------------------------------------------------------------------+
//| MSNR Scalper EA - MSNR-like Support/Resistance + MA scalping     |
//| Notes: This is a configurable scaffold for backtesting and live  |
//| trading. It does NOT guarantee returns. Use backtest-first.      |
//+------------------------------------------------------------------+
#property copyright ""
#property link      ""
#property version   "1.0"

#include <Trade\Trade.mqh>
input int InpFastMA = 5;
input int InpSlowMA = 20;

input ENUM_TIMEFRAMES InpTimeframe = PERIOD_M5; // primary timeframe (all TF supported)

// Trade controls: trade only on M1 and M5 (can enable/disable)
input bool TradeOnM1 = true;
input bool TradeOnM5 = true;

// Risk modes: 0=minimal,1=average,2=maximum
input int RiskMode = 1;
input double RiskMinimal = 0.25; // percent
input double RiskAverage = 1.0;  // percent
input double RiskMaximum = 5.0;  // percent

input double TakeProfitPips = 6.0;
input double StopLossPips = 8.0;
input double MaxDailyLossPercent = 20.0; // safety hard stop

input bool AllowMultipleTrades = true;
input int MaxTradesPerSymbolPerDay = 50;
input bool ConfirmMultiTF = true; // require higher timeframe trend confirmation

// internal
CTrade trade;
datetime lastTradeTime = 0;
int tradesToday = 0;
double dayStartBalance = 0.0;

double GetRiskPercentByMode()
  {
   if(RiskMode==0) return(RiskMinimal);
   if(RiskMode==2) return(RiskMaximum);
   return(RiskAverage);
  }

double CalculateLotSize(double riskPercent, double slPips)
  {
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskMoney = balance * riskPercent / 100.0;
   double point = SymbolInfoDouble(_Symbol,SYMBOL_POINT);
   double contractSize = SymbolInfoDouble(_Symbol,SYMBOL_TRADE_CONTRACT_SIZE);
   double tickValue = SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_VALUE);
   if(tickValue<=0) tickValue = 0.0001; // fallback
  double slValuePerLot = slPips * point * (tickValue/point); // approx value per lot for SL distance
   if(slValuePerLot<=0) return(SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN));
   double lots = riskMoney / slValuePerLot;
   double lotStep = SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
   double minLot = SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
   if(lotStep<=0) lotStep = 0.01;
   double normalized = MathFloor(lots/lotStep)*lotStep;
   if(normalized<minLot) normalized = minLot;
   return(normalized);
  }

// Simple recent high/low support-resistance detection
void GetRecentSR(double &support, double &resistance)
  {
   int lookback = 50; // bars
   double highest = -1.0;
   double lowest = DBL_MAX;
   for(int i=1;i<=lookback;i++)
     {
      double h = iHigh(_Symbol, InpTimeframe, i);
      double l = iLow(_Symbol, InpTimeframe, i);
      if(h>highest) highest=h;
      if(l<lowest) lowest=l;
     }
   support = lowest;
   resistance = highest;
  }

bool IsMAFastAbove()
  {
  double maFast = iMA(_Symbol, InpTimeframe, InpFastMA,0,MODE_SMA,PRICE_CLOSE,1);
  double maSlow = iMA(_Symbol, InpTimeframe, InpSlowMA,0,MODE_SMA,PRICE_CLOSE,1);
  double maFastPrev = iMA(_Symbol, InpTimeframe, InpFastMA,0,MODE_SMA,PRICE_CLOSE,2);
  double maSlowPrev = iMA(_Symbol, InpTimeframe, InpSlowMA,0,MODE_SMA,PRICE_CLOSE,2);
   return(maFast>maSlow && maFastPrev<=maSlowPrev);
  }

bool IsMAFastBelow()
  {
   double maFast = iMA(_Symbol, InpTimeframe, InpFastMA,0,MODE_SMA,PRICE_CLOSE,1);
   double maSlow = iMA(_Symbol, InpTimeframe, InpSlowMA,0,MODE_SMA,PRICE_CLOSE,1);
   double maFastPrev = iMA(_Symbol, InpTimeframe, InpFastMA,0,MODE_SMA,PRICE_CLOSE,2);
   double maSlowPrev = iMA(_Symbol, InpTimeframe, InpSlowMA,0,MODE_SMA,PRICE_CLOSE,2);
   return(maFast<maSlow && maFastPrev>=maSlowPrev);
  }

void PlaceOrder(bool isBuy)
  {
   double riskPct = GetRiskPercentByMode();
   double slPips = StopLossPips;
   double tpPips = TakeProfitPips;
   double lots = CalculateLotSize(riskPct, slPips);
   if(lots<=0) return;
  double point = SymbolInfoDouble(_Symbol,SYMBOL_POINT);
   double price = isBuy?SymbolInfoDouble(_Symbol,SYMBOL_ASK):SymbolInfoDouble(_Symbol,SYMBOL_BID);
  // ensure sl/tp comply with broker's min distance and symbol digits
  int digits = (int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);
  double minStopLevel = (double)SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL);
  if(minStopLevel<=0) minStopLevel = 10; // points
  double sl = isBuy?price - slPips*point:price + slPips*point;
  double tp = isBuy?price + tpPips*point:price - tpPips*point;
  // adjust distances
  double stopDistance = MathAbs(price - sl)/point;
  if(stopDistance < minStopLevel) {
    double adjust = (minStopLevel - stopDistance + 1) * point;
    if(isBuy) sl = sl - adjust; else sl = sl + adjust;
  }
  sl = NormalizeDouble(sl, digits);
  tp = NormalizeDouble(tp, digits);
   bool ok=false;
   if(isBuy) ok = trade.Buy(lots,NULL,price,sl,tp,NULL);
   else ok = trade.Sell(lots,NULL,price,sl,tp,NULL);
   if(ok)
     {
      lastTradeTime = TimeCurrent();
      tradesToday++;
    // log trade to file
    int handle = FileOpen("ea_trades.csv",FILE_READ|FILE_WRITE|FILE_CSV|FILE_ANSI);
    if(handle!=INVALID_HANDLE)
      {
      // move to end
      FileSeek(handle,0,SEEK_END);
      string line = TimeToString(TimeCurrent(),TIME_DATE|TIME_SECONDS) + "," + (isBuy?"BUY":"SELL") + "," + DoubleToString(lots,2) + "," + DoubleToString(price,Digits()) + "," + DoubleToString(sl,Digits()) + "," + DoubleToString(tp,Digits());
      FileWriteString(handle,line+"\n");
      FileClose(handle);
      }
     }
  else
    {
    // optional: log failure reason
    }
  }

// Called from trade events to log exits; in MQL5 we'd normally use OnTrade or check positions
void LogTradeExit(bool isBuy,double entry,double exit,double lots)
  {
   double pl = (isBuy? (exit-entry) : (entry-exit));
   pl /= SymbolInfoDouble(_Symbol,SYMBOL_POINT); // in pips-like units
   int handle = FileOpen("ea_trades.csv",FILE_READ|FILE_WRITE|FILE_CSV|FILE_ANSI);
   if(handle!=INVALID_HANDLE)
     {
      FileSeek(handle,0,SEEK_END);
      string line = TimeToString(TimeCurrent(),TIME_DATE|TIME_SECONDS) + ",EXIT," + (isBuy?"BUY":"SELL") + "," + DoubleToString(lots,2) + "," + DoubleToString(entry,Digits()) + "," + DoubleToString(exit,Digits()) + "," + DoubleToString(pl,2);
      FileWriteString(handle,line+"\n");
      FileClose(handle);
     }
  }

// Minimal OnTradeTransaction to record closed deals to file
void OnTradeTransaction(const MqlTradeTransaction &trans,const MqlTradeRequest &request,const MqlTradeResult &result)
  {
   // record deal add events
   if(trans.type==TRADE_TRANSACTION_DEAL_ADD)
     {
      ulong deal = trans.deal;
      if(deal>0)
        {
         // select deal from history
         if(HistoryDealSelect(deal))
           {
            long entry = (long)HistoryDealGetInteger(deal, DEAL_ENTRY);
            double price = HistoryDealGetDouble(deal, DEAL_PRICE);
            double volume = HistoryDealGetDouble(deal, DEAL_VOLUME);
            // entry==DEAL_ENTRY_OUT indicates an exit deal
            if(entry==DEAL_ENTRY_OUT)
              {
               // attempt to map to buy/sell by checking deal type
               long type = (long)HistoryDealGetInteger(deal, DEAL_TYPE);
               bool isBuy = (type==DEAL_TYPE_BUY || type==DEAL_TYPE_BUY_LIMIT || type==DEAL_TYPE_BUY_STOP);
               LogTradeExit(isBuy, 0.0, price, volume);
              }
           }
        }
     }
  }


int OnInit()
  {
   return(INIT_SUCCEEDED);
  }

void OnDeinit(const int reason)
  {
  }

void OnTick()
  {
   // daily reset
   if(lastTradeTime>0 && TimeDay(TimeCurrent())!=TimeDay(lastTradeTime))
     tradesToday = 0;

   // Safety: limit trades per day
   if(tradesToday>=MaxTradesPerSymbolPerDay && MaxTradesPerSymbolPerDay>0) return;

   double support,resistance;
   GetRecentSR(support,resistance);

   // Evaluate both 1m and 5m MA cross signals
   // M1
   if(TradeOnM1)
     {
      bool m1Buy = iMA(_Symbol,PERIOD_M1,InpFastMA,0,MODE_SMA,PRICE_CLOSE,1) > iMA(_Symbol,PERIOD_M1,InpSlowMA,0,MODE_SMA,PRICE_CLOSE,1) &&
                   iMA(_Symbol,PERIOD_M1,InpFastMA,0,MODE_SMA,PRICE_CLOSE,2) <= iMA(_Symbol,PERIOD_M1,InpSlowMA,0,MODE_SMA,PRICE_CLOSE,2);
      bool m1Sell = iMA(_Symbol,PERIOD_M1,InpFastMA,0,MODE_SMA,PRICE_CLOSE,1) < iMA(_Symbol,PERIOD_M1,InpSlowMA,0,MODE_SMA,PRICE_CLOSE,1) &&
                    iMA(_Symbol,PERIOD_M1,InpFastMA,0,MODE_SMA,PRICE_CLOSE,2) >= iMA(_Symbol,PERIOD_M1,InpSlowMA,0,MODE_SMA,PRICE_CLOSE,2);
      if(m1Buy)
        {
         bool ok=true;
         if(ConfirmMultiTF)
           {
            // require M5 trend to be bullish
            double m5Fast = iMA(_Symbol,PERIOD_M5,InpFastMA,0,MODE_SMA,PRICE_CLOSE,1);
            double m5Slow = iMA(_Symbol,PERIOD_M5,InpSlowMA,0,MODE_SMA,PRICE_CLOSE,1);
            if(m5Fast<=m5Slow) ok=false;
           }
         if(ok)
            PlaceOrder(true);
        }
      else if(m1Sell)
        {
         bool ok=true;
         if(ConfirmMultiTF)
           {
            double m5Fast = iMA(_Symbol,PERIOD_M5,InpFastMA,0,MODE_SMA,PRICE_CLOSE,1);
            double m5Slow = iMA(_Symbol,PERIOD_M5,InpSlowMA,0,MODE_SMA,PRICE_CLOSE,1);
            if(m5Fast>=m5Slow) ok=false;
           }
         if(ok)
            PlaceOrder(false);
        }
     }

   // M5
   if(TradeOnM5)
     {
      bool m5Buy = iMA(_Symbol,PERIOD_M5,InpFastMA,0,MODE_SMA,PRICE_CLOSE,1) > iMA(_Symbol,PERIOD_M5,InpSlowMA,0,MODE_SMA,PRICE_CLOSE,1) &&
                   iMA(_Symbol,PERIOD_M5,InpFastMA,0,MODE_SMA,PRICE_CLOSE,2) <= iMA(_Symbol,PERIOD_M5,InpSlowMA,0,MODE_SMA,PRICE_CLOSE,2);
      bool m5Sell = iMA(_Symbol,PERIOD_M5,InpFastMA,0,MODE_SMA,PRICE_CLOSE,1) < iMA(_Symbol,PERIOD_M5,InpSlowMA,0,MODE_SMA,PRICE_CLOSE,1) &&
                    iMA(_Symbol,PERIOD_M5,InpFastMA,0,MODE_SMA,PRICE_CLOSE,2) >= iMA(_Symbol,PERIOD_M5,InpSlowMA,0,MODE_SMA,PRICE_CLOSE,2);
      if(m5Buy)
        {
         bool ok=true;
         if(ConfirmMultiTF)
           {
            // require H1 trend to be bullish
            double h1Fast = iMA(_Symbol,PERIOD_H1,InpFastMA,0,MODE_SMA,PRICE_CLOSE,1);
            double h1Slow = iMA(_Symbol,PERIOD_H1,InpSlowMA,0,MODE_SMA,PRICE_CLOSE,1);
            if(h1Fast<=h1Slow) ok=false;
           }
         if(ok)
            PlaceOrder(true);
        }
      else if(m5Sell)
        {
         bool ok=true;
         if(ConfirmMultiTF)
           {
            double h1Fast = iMA(_Symbol,PERIOD_H1,InpFastMA,0,MODE_SMA,PRICE_CLOSE,1);
            double h1Slow = iMA(_Symbol,PERIOD_H1,InpSlowMA,0,MODE_SMA,PRICE_CLOSE,1);
            if(h1Fast>=h1Slow) ok=false;
           }
         if(ok)
            PlaceOrder(false);
        }
     }
  }

//+------------------------------------------------------------------+
